"""
Reshapes C source code to fit inside a text-based stencil pattern while strictly
preserving syntactic correctness and original whitespace requirements.

The script operates in three main phases:

1. Preservation Tokenizer:
   Parses the C source into atomic tokens (identifiers, operators, strings) using regex.
   Crucially, it captures the *existence* of whitespace between tokens in the original
   file. This ensures that mandatory separators (e.g., between `int` and `main`) are
   maintained, while allowing flexible spacing where valid (e.g., around `+` or `=`).

2. High-Density Layout Solver (Dynamic Programming):
   Uses a Dynamic Programming (DP) algorithm to find the optimal distribution of
   tokens into the stencil's `*` slots.
   - State: Tracks the minimum cost to place `N` tokens.
   - Cost Function: `unused_space  3`. This cubic penalty aggressively punishes
     slots that are not filled to capacity. This forces the solver to "look ahead"
     and choose token groupings that pack the code as tightly as possible, eliminating
     visual gaps.
   - Look-Ahead: Checks dozens of potential token combinations for every slot to
     ensure large tokens (like `return`) don't get stranded in small columns.

3. Justified Renderer:
   Reconstructs the output line-by-line, merging the static stencil art with the
   formatted code.
   - Applies full text justification (flush left and right) within each slot.
   - Distributes necessary padding spaces evenly between tokens, ensuring valid C
     syntax is never broken.

Usage:
    python shape_code.py <source_code.c> <stencil.txt> <output.c>
"""

import sys
import re

# -----------------------------------------------------------------------------
# Strict Preservation Tokenizer
# -----------------------------------------------------------------------------

def get_token_pattern():
    """
    Captures C tokens.
    Complex operators (like >>=) are matched first to prevent splitting.
    """
    return re.compile(
        r'(?P<string>\"(?:\\.|[^\\\"])*\")|'   # String literals
        r'(?P<char>\'(?:\\.|[^\\\'])*\')|'     # Char literals
        r'(?P<hex>0x[0-9a-fA-F]+)|'            # Hex
        r'(?P<number>\d+)|'                    # Decimal
        r'(?P<ident>[a-zA-Z_]\w*)|'            # Identifiers
        r'(?P<op>>>|<<|==|!=|<=|>=|->|&&|\|\||\+\+|--|\+=|-=|\*=|/=|%=|&=|\^=|\|=)|'
        r'(?P<punct>[^\s])'                    # Punctuation
    )

class Token:
    def __init__(self, text, space_after_len):
        self.text = text
        # Minimum space required after this token.
        # We strictly preserve the *existence* of space (1 or 0),
        # but allow the renderer to expand it for justification.
        self.min_space = space_after_len

def tokenize(code_string):
    tokens = []
    pattern = get_token_pattern()

    # Clean leading/trailing whitespace to avoid artifacts
    code_string = code_string.strip()

    matches = list(pattern.finditer(code_string))

    for i, match in enumerate(matches):
        start, end = match.span()
        text = match.group()

        # Determine gap to next token
        if i < len(matches) - 1:
            next_start = matches[i+1].start()
            gap_str = code_string[end:next_start]
            # If original had ANY space (newline, tab, etc), we require at least 1 space.
            # If it had none (e.g. "a+b"), we require 0.
            space_len = 1 if gap_str.strip() == "" and len(gap_str) > 0 else 0
        else:
            space_len = 0

        tokens.append(Token(text, space_len))

    return tokens

# -----------------------------------------------------------------------------
# Slot Generation
# -----------------------------------------------------------------------------

class Slot:
    def __init__(self, id, width, prefix):
        self.id = id
        self.width = width
        self.prefix = prefix
        self.tokens = [] # Assigned by solver

def generate_slots(stencil_lines, min_tokens):
    """Generates a stream of slots from the stencil."""
    slots = []
    slot_id = 0
    line_idx = 0

    # Generate enough slots to definitely fit code.
    # We buffer generously because the solver will stop exactly when code is done.
    while len(slots) < min_tokens + 2000:
        if line_idx < len(stencil_lines):
            template = stencil_lines[line_idx]
        else:
            # Infinite repeat of the last valid stencil line pattern
            template = "********************"
            for l in reversed(stencil_lines):
                if '*' in l:
                    template = l
                    break

        last_pos = 0
        for match in re.finditer(r'\*+', template):
            prefix = template[last_pos:match.start()]
            width = match.end() - match.start()
            slots.append(Slot(slot_id, width, prefix))
            slot_id += 1
            last_pos = match.end()

        line_idx += 1
        if line_idx > 100000: break # Safety

    return slots

# -----------------------------------------------------------------------------
# High-Density Layout Solver (Dynamic Programming)
# -----------------------------------------------------------------------------

def solve_layout(tokens, slots):
    """
    Finds the layout that minimizes 'unused space' using a cubic cost function.
    This forces the text to pack as tightly as possible (High Density).
    """

    # dp[token_idx] = cost
    current_states = {0: 0}

    # history[slot_idx][token_idx] = (prev_token_idx, count)
    history = []

    total_tokens = len(tokens)
    final_slot_idx = -1

    # Penalties
    COST_EMPTY_SLOT = 1000000 # Avoid skipping slots unless impossible

    for slot_idx, slot in enumerate(slots):
        next_states = {}
        moves = {}

        if not current_states: break

        # Pruning: Keep top 1000 cheapest paths (Increased beam width for better optimization)
        sorted_states = sorted(current_states.items(), key=lambda x: x[1])
        active_states = sorted_states[:1000]

        for t_idx, cost in active_states:

            # --- Terminal State Check ---
            if t_idx == total_tokens:
                # We finished the code. Record where we finished.
                # We do NOT extend this path further (no adding empty slots at the end).
                if final_slot_idx == -1: final_slot_idx = slot_idx - 1
                continue

            # --- Option 1: Skip Slot ---
            # Very high cost. We hate holes.
            skip_cost = cost + (slot.width ** 3) + COST_EMPTY_SLOT
            if skip_cost < next_states.get(t_idx, float('inf')):
                next_states[t_idx] = skip_cost
                moves[t_idx] = (t_idx, 0)

            # --- Option 2: Fill Slot ---
            current_len = 0

            # Deep Lookahead: Try fitting up to 60 tokens (cover wide lines)
            for k in range(1, 60):
                if t_idx + k > total_tokens: break

                tok = tokens[t_idx + k - 1]

                # Length: Text + Required Space
                added = len(tok.text)
                if k > 1:
                    prev_tok = tokens[t_idx + k - 2]
                    added += prev_tok.min_space

                current_len += added

                if current_len <= slot.width:
                    # Fits. Calculate Density Cost.
                    unused = slot.width - current_len

                    # CUBIC COST: penalizes loose spacing aggressively.
                    # Unused 10 -> Cost 1000. Unused 2 -> Cost 8.
                    step_cost = unused ** 3

                    new_cost = cost + step_cost
                    new_t = t_idx + k

                    if new_cost < next_states.get(new_t, float('inf')):
                        next_states[new_t] = new_cost
                        moves[new_t] = (t_idx, k)
                else:
                    # Overflow
                    break

        history.append(moves)
        current_states = next_states

        # Optimization: Stop generating if we found a finish line well behind us
        if final_slot_idx != -1 and slot_idx > final_slot_idx + 5:
            break

    # --- Reconstruct ---
    if final_slot_idx == -1:
        print("Warning: Could not fit all code. Output will be truncated.")
        final_slot_idx = len(history) - 1
        curr_t = max(history[-1].keys()) if history else 0
    else:
        curr_t = total_tokens

    # Backtrack
    scan = final_slot_idx
    while scan >= 0:
        if curr_t in history[scan]:
            prev_t, count = history[scan][curr_t]
            slots[scan].tokens = tokens[prev_t : prev_t + count]
            curr_t = prev_t
        scan -= 1

    return final_slot_idx

# -----------------------------------------------------------------------------
# Renderer
# -----------------------------------------------------------------------------

def render_slot(slot):
    if not slot.tokens:
        return " " * slot.width

    content_len = 0
    for i, t in enumerate(slot.tokens):
        content_len += len(t.text)
        if i < len(slot.tokens) - 1:
            content_len += t.min_space

    padding_needed = slot.width - content_len

    # Single Token Case: Left Align
    if len(slot.tokens) == 1:
        return slot.tokens[0].text.ljust(slot.width)

    # Multi-Token: Full Justify
    gaps = len(slot.tokens) - 1
    base_pad = padding_needed // gaps
    rem_pad = padding_needed % gaps

    res = slot.tokens[0].text
    for i in range(gaps):
        t_curr = slot.tokens[i]
        t_next = slot.tokens[i+1]

        # Space = Mandatory Source Space + Justification Padding
        total_space = t_curr.min_space + base_pad + (1 if i < rem_pad else 0)

        res += (" " * total_space) + t_next.text

    return res

def process(c_path, stencil_path, out_path):
    # Read Inputs
    with open(c_path, 'r') as f:
        lines = f.readlines()
    defines = [x.strip() for x in lines if x.strip().startswith('#')]
    # Collapse code to single string, preserving internal spacing structure
    code_body = " ".join([x.strip() for x in lines if not x.strip().startswith('#')])

    tokens = tokenize(code_body)

    with open(stencil_path, 'r') as f:
        # Expand tabs to spaces for accurate width calculation
        stencil_lines = [line.rstrip('\n').expandtabs(4) for line in f]

    # Solve
    all_slots = generate_slots(stencil_lines, len(tokens))
    last_used_idx = solve_layout(tokens, all_slots)

    # Output
    output_lines = []

    def get_template(i):
        if i < len(stencil_lines): return stencil_lines[i]
        for l in reversed(stencil_lines):
            if '*' in l: return l
        return "********************"

    current_slot = 0
    line_idx = 0

    while current_slot <= last_used_idx:
        template = get_template(line_idx)

        if '*' not in template:
            output_lines.append(template)
            line_idx += 1
            continue

        new_line = ""
        last_pos = 0

        for match in re.finditer(r'\*+', template):
            new_line += template[last_pos:match.start()]

            if current_slot <= last_used_idx:
                new_line += render_slot(all_slots[current_slot])
            else:
                new_line += " " * (match.end() - match.start())

            current_slot += 1
            last_pos = match.end()

        new_line += template[last_pos:]
        output_lines.append(new_line)
        line_idx += 1

        if line_idx > 50000: break

    # Write
    with open(out_path, 'w') as f:
        if defines:
            f.write("\n".join(defines) + "\n\n")
        for l in output_lines:
            f.write(l + "\n")

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Syntax: python shape_code.py <c_source> <stencil> <output>")
        sys.exit(1)

    process(sys.argv[1], sys.argv[2], sys.argv[3])
