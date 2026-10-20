"""
Crunch the code for IOCCC
- Remove comments and #if DEBUG blocks
- Remove all whitespace
- Turn all hex numbers to decimal
"""
import sys
import re
import os
import itertools
from pprint import pprint
import string

# Globals
#global_vars = set("A B C D E F H L HL RP".split())
global_vars = set("A F HL RP".split())

# Locals
# FIXME reduce number of local variables to win!
local_vars = set("a c d e f g h k n o p q r v x y z".split())
# Free: b i j l m s t

# A B C D E F G H I J K L M N O P Q R S T U V W X Y Z
# GAMEBOY: C D F H I J K L N P Q R S T U V W X Z

# FIXME remove the # defines for these from the source and
# print their values at the end for the makefile
to_move_to_makefile = (
    "RB_PC_INC",
    "INITIAL_REGS",
    "KEYS",
)

# Global vars and macros to shorten
# nm --defined-only --extern-only gb.o | awk '{print $3}'
replacements = {
    # defines
    "F": "G",
    "A": "A",
    "HL":"M",
    "Z_FLAG":"E",
    "C_FLAG":"B",
    "IF_Y":"O",
    "IF_Y_EQ":"Y",
    "grd16":"_",
    "rd16":"S",

    # removed
    "INITIAL_REGS": "R",
    "KEYS": "K",
    "RB_PC_INC":"C",

    # subbed
    "mem": "D",
    "pc":"F",
    "offset":"H",
    "rb":"I",
    "sp":"J",
    "reg":"t",
    "SETF":"L",
    "wb":"N",
    "SET_RP":"P",
    "push":"Q",
    "ime":"w",
    "RP":"Z",
    "ei":"T",
    "buttons":"U",
    "SET_REG":"V",
    "GET_REG":"W",
    "halt":"X",
    "frame":"s",
    "tmp":"b",
    "get_pixel_idx":"i",
    "alu":"j",
    "u16":"l",
    "cpu_step":"m",
    "u8":"u",
}
inv_replacements = {v: k for k, v in replacements.items()}

# Squash character sequences
to_squash = (
    (
        replacements["IF_Y_EQ"],
        "if(y==",
        f'#define {replacements["IF_Y_EQ"]} {replacements["IF_Y"]} ==',
        6,
    ),
    (
        replacements["IF_Y"],
        "if(y",
        f'#define {replacements["IF_Y"]} if(y',
        6,
    ),
    (
        replacements["RB_PC_INC"],
        f'{replacements["rb"]}({replacements["pc"]}++)',
        f'#define {replacements["RB_PC_INC"]} {replacements["rb"]}({replacements["pc"]}++)',
        -1,
    ),
)


def decomment(content):
    """
    Removes comments and #if DEBUG blocks from content.
    """
    # Strings: Match double or single quoted strings (ignoring escaped quotes)
    # We catch these to PRESERVE them.
    # Pattern explanation: Quote, then (non-quote OR escaped char)*, then Quote
    str_pat = r'("[^"\\]*(?:\\.[^"\\]*)*"|\'[^\'\\]*(?:\\.[^\'\\]*)*\')'

    # Debug Block: Matches #if DEBUG ... #endif /*DEBUG*/
    # ^ matches start of line (multiline mode).
    # [\s\S]*? matches any character non-greedily until the closing tag.
    debug_pat = r'^\s*#if\s+DEBUG[\s\S]*?#endif\s*/\*DEBUG\*/'

    # Block Comments: /* ... */
    blk_cmt_pat = r'/\*[\s\S]*?\*/'

    # Line Comments: // ... (until end of line)
    # [^\n]* matches everything except the newline.
    line_cmt_pat = r'//[^\n]*'

    # Combine patterns.
    # The order for the "Remove" group is roughly specific-to-general.
    # We use a capture group for the String (Group 1) and a combined group for things to delete.
    pattern = re.compile(
        f'{str_pat}|({debug_pat}|{blk_cmt_pat}|{line_cmt_pat})',
        re.MULTILINE | re.DOTALL
    )

    def replacer(match):
        # If the match captured group 1 (the string), return it exactly as is.
        if match.group(1):
            return match.group(1)
        # Otherwise, it matched one of the comments or debug blocks; return empty string.
        return ""

    # Perform the substitution
    content = pattern.sub(replacer, content)

    # Trim Trailing Whitespace
    content = re.sub(r'[ \t]+$', '', content, flags=re.MULTILINE)

    # Squash Repeated Newlines
    content = re.sub(r'\n{2,}', '\n', content)

    return content

def c_name_generator():
    """
    Generate valid C identifiers
    """
    # C identifiers: First char cannot be a digit
    first_char_options = "_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    following_char_options = first_char_options + "0123456789"
    
    # C keywords
    c_keywords = {
        "auto", "break", "case", "char", "const", "continue", "default", "do",
        "double", "else", "enum", "extern", "float", "for", "goto", "if",
        "int", "long", "register", "return", "short", "signed", "sizeof", "static",
        "struct", "switch", "typedef", "union", "unsigned", "void", "volatile", "while"
    }

    # Avoid any of these
    avoid = c_keywords|global_vars|local_vars

    length = 1
    while True:
        # Generate all combinations for the current length
        # First char is handled separately from the rest
        if length == 1:
            for char in first_char_options:
                if char not in avoid:
                    yield char
        else:
            # product() creates a cartesian product of the input iterables
            for first in first_char_options:
                remainder_length = length - 1
                for rest in itertools.product(following_char_options, repeat=remainder_length):
                    name = first + "".join(rest)
                    if name not in avoid:
                        yield name
        length += 1

make_identifier = c_name_generator()

def re_for_name(name):
    """
    Return the regexp to match symbol name
    """
    start_boundary = r'\b' if re.match(r'^\w', name) else ''
    end_boundary = r'\b' if re.search(r'\w$', name) else ''
    return start_boundary + re.escape(name) + end_boundary

def replace(prog: str) -> str:
    """
    replace high frequency identifiers into shorter ones
    """
    for name, replacement in replacements.items():
        found = len(re.findall(re_for_name(name), prog))
        if found == 0:
            print(f"Didn't find {name} to replace")
            continue
        global_vars.add(replacement)
        print(f"replacement for {name} (found {found} times) is {replacement}")
        pattern = re_for_name(name)
        prog = re.sub(pattern, replacement, prog)
    return prog
    
def strip_whitespace(prog: str) -> str:
    """
    Strips the maximum allowed whitespace from a C program string without 
    breaking valid syntax.
    
    Handles:
    - String literals (" ") and Character literals (' ')
    - Single line (//) and Block (/* */) comments
    - Preprocessor directives (#)
    - Token separation (ensures 'int main' doesn't become 'intmain')
    - Intelligent punctuation merging (ensures ') {' becomes '){')
    """
    
    # State flags
    in_string = False
    in_char = False
    in_block_comment = False
    in_line_comment = False
    in_preprocessor = False
    
    result = []
    length = len(prog)
    i = 0
    
    # Helpers
    def is_alnum(c):
        return c.isalnum() or c == '_' or c == '$'
    
    # Characters that act as operators and might combine (e.g., + and + -> ++)
    # We exclude separators like { } ( ) ; , [ ] which are safe to merge.
    operator_chars = set("+-*/%<>=!&|^~?:.")

    space_pending = False

    while i < length:
        char = prog[i]
        next_char = prog[i+1] if i + 1 < length else ''
        
        # --- 1. Handle Comments (Highest Priority to strip them) ---
        if in_block_comment:
            if char == '*' and next_char == '/':
                in_block_comment = False
                i += 2
                # A comment is technically a separator (int/*...*/x -> int x)
                space_pending = True 
                continue
            i += 1
            continue

        if in_line_comment:
            if char == '\n':
                in_line_comment = False
                # If inside preprocessor, this newline terminates the directive
                if in_preprocessor:
                    result.append('\n')
                    in_preprocessor = False
                    space_pending = False
                else:
                    space_pending = True
            elif char == '\\' and next_char == '\n':
                # Line splicing inside a comment (keeps comment alive on next line)
                i += 2
                continue
            i += 1
            continue

        # --- 2. Check for start of Comments ---
        # (Must check before strings to handle cases like "/*" inside comments)
        if not in_string and not in_char:
            if char == '/' and next_char == '*':
                in_block_comment = True
                i += 2
                continue
            if char == '/' and next_char == '/':
                in_line_comment = True
                i += 2
                continue

        # --- 3. Handle Strings and Chars ---
        if in_string:
            result.append(char)
            if char == '\\': # Handle escapes
                if next_char:
                    result.append(next_char)
                    i += 1
            elif char == '"':
                in_string = False
            i += 1
            continue

        if in_char:
            result.append(char)
            if char == '\\': 
                if next_char:
                    result.append(next_char)
                    i += 1
            elif char == "'":
                in_char = False
            i += 1
            continue

        # --- 4. Handle Preprocessor Start ---
        # A '#' starts a directive if we aren't in a string/comment.
        # We must ensure it starts on a new line (unless it's the very first char).
        if char == '#':
            # Check if we need to insert a newline to fix 'int x;#define...'
            if result and result[-1] != '\n':
                result.append('\n')
            
            in_preprocessor = True
            result.append(char)
            space_pending = False
            i += 1
            continue

        # --- 5. Handle Whitespace ---
        if char.isspace():
            if in_preprocessor and char == '\n':
                # End of preprocessor directive
                result.append('\n')
                in_preprocessor = False
                space_pending = False
            else:
                space_pending = True
            i += 1
            continue

        # --- 6. Handle Line Splicing (Backslash + Newline) ---
        # In C, ending a line with \ joins it with the next. 
        # Crucial for multi-line #defines.
        if char == '\\' and next_char == '\n':
            i += 2 # Skip both, effectively merging the lines
            # Note: We do NOT set space_pending. 'Abc\ \ndef' becomes 'Abcdef'.
            continue

        # --- 7. Output Normal Characters (THE FIX IS HERE) ---
        
        if space_pending:
            last = result[-1] if result else ''
            
            if in_preprocessor:
                # SAFE MODE: In Preprocessor, preserve existence of spaces strictly.
                result.append(' ')
            else:
                # AGGRESSIVE MODE: In normal code, merge tokens if safe.
                
                # Case A: Alnum + Alnum (int main -> Space needed)
                if is_alnum(last) and is_alnum(char):
                    result.append(' ')
                
                # Case B: Op + Op ( + + -> Space needed to prevent ++)
                # We only assume danger if both are in the 'operator_chars' set.
                # This allows combining safe puncts like ')' and '{' -> '){'
                elif last in operator_chars and char in operator_chars:
                    result.append(' ')
            
            space_pending = False

        # Start of string/char literals triggers state change for NEXT loop
        if char == '"': in_string = True
        if char == "'": in_char = True

        result.append(char)
        i += 1

    return "".join(result).strip()

def add_define(prog, define):
    """
    Find the end of the defines and includes and add one
    """
    headers, code = split_source(prog)
    return headers + define+"\n" + code

def hex_to_decimal(prog: str) -> str:
    """
    Transforms all hex numbers (e.g., 0xFF, 0x10UL) in the C program 
    to their decimal equivalents (e.g., 255, 16UL).
    
    Assumptions: 
    - The input 'prog' contains NO comments and NO string literals.
    """

    m = re.search(r"offset=(-?(?:0x)?[0-9A-F]+)\s*[,;]", prog)
    assert m, "didn't find offset="
    offset = int(m.group(1), 0)
    if offset < 0:
        offset += 0x10000
    print(f"Offset = {offset}")
    prog = prog.replace(f"offset={m.group(1)}", "OFFSET")
    
    # Pattern explanation:
    # \b            -> Word boundary (ensures we don't match inside var0xFF)
    # 0[xX]         -> Matches the literal prefix 0x or 0X
    # ([0-9a-fA-F]+)-> Group 1: Matches the hex digits
    # ([uUlL]*)     -> Group 2: Matches optional integer suffixes (U, L, LL, etc.)
    # \b            -> Word boundary (ensures we don't match 0xFFgarbage)
    pattern = r'\b0[xX]([0-9a-fA-F]+)([uUlL]*)\b'

    def replacer(match):
        hex_digits = match.group(1)
        suffix = match.group(2)
        
        # Convert hex string to integer object
        decimal_value = int(hex_digits, 16)

        # Try replacing value with offset+/-const
        delta = decimal_value - offset
        if delta == 0:
            test_value = "I"
        elif delta > 0:
            test_value = f"I+{delta}"
        else:
            test_value = f"I-{-delta}"
        if len(test_value)<len(str(decimal_value)):
            decimal_value = "offset"+test_value[1:]
        
        # Return as string + original suffix
        return f"{decimal_value}{suffix}"

    # re.sub finds all non-overlapping occurrences and replaces them
    prog = re.sub(pattern, replacer, prog)
    prog = prog.replace("OFFSET", f"offset={offset}")
    return prog

def split_source(source_code):
    """
    Separates preprocessor directives (lines starting with #) from the main code.
    Assumes standard C formatting where directives end with a newline.
    """
    lines = source_code.splitlines(keepends=True)
    header_lines = []
    body_lines = []
    
    for line in lines:
        # Check if line is a preprocessor directive
        if line.strip().startswith("#"):
            header_lines.append(line)
        else:
            body_lines.append(line)
            
    return "".join(header_lines), "".join(body_lines)

def compress_c_code(source_code):
    # Split the code so we don't mess up includes/defines
    existing_header, body_code = split_source(source_code)
    
    new_defines = []
    current_body = body_code
    
    # Search parameters
    min_len = 2
    max_len = 60 

    while True:
        best_candidate = None
        best_savings = 0
        
        # Optimization: Scanning the body length once per pass
        n = len(current_body)
        
        # We only care about substrings that appear at least twice
        # To optimize speed, we can use a dictionary to track counts
        candidates = {}

        # Iterate through all possible substring lengths
        for length in range(max_len, min_len - 1, -1):
            for i in range(n - length + 1):
                sub = current_body[i : i + length]
                
                if sub in candidates:
                    continue
                
                # Check occurrence in the BODY only
                count = current_body.count(sub)
                
                if count < 2:
                    candidates[sub] = 0
                    continue
                
                # Cost Analysis
                # Cost to add define: #define XX string\n
                # 11 chars (#define XX ) + length + 1 char (\n)
                define_overhead = 12 + length
                
                # Cost to replace: 2 chars * count
                replacement_cost = 2 * count
                
                # Original bulk: length * count
                original_cost = length * count
                
                savings = original_cost - (replacement_cost + define_overhead)
                
                candidates[sub] = savings

                if savings > best_savings:
                    best_savings = savings
                    best_candidate = sub

        if best_savings <= 0 or best_candidate is None:
            break
            
        macro_name = next(make_identifier)

        # Apply replacement ONLY to the body
        new_defines.append(f"#define {macro_name} {best_candidate}")
        current_body = current_body.replace(best_candidate, macro_name)
        
        print(f"Define {macro_name} = '{best_candidate}' (Saved {best_savings} bytes)")

    # 3. Reassemble
    # Ensure existing header ends with a newline if it exists
    if existing_header and not existing_header.endswith('\n'):
        existing_header += '\n'
        
    defines_block = "\n".join(new_defines)
    if defines_block:
        defines_block += "\n"
    
    return existing_header + defines_block + current_body

def minimize_ioccc_score(program: str) -> str:
    """
    Inserts a space after ';', '{', or '}' if one does not exist,
    ignoring occurrences inside string or character literals.
    This reduces the IOCCC Rule 2b size score.
    """
    output = []
    in_string = False
    quote_char = None
    i = 0
    length = len(program)

    while i < length:
        char = program[i]

        if in_string:
            output.append(char)
            if char == '\\':
                # Handle escape sequence (e.g. \" or \\): 
                # strictly consume next char so it isn't treated as a quote
                if i + 1 < length:
                    output.append(program[i+1])
                    i += 1
            elif char == quote_char:
                # Closing quote found
                in_string = False
                quote_char = None
        else:
            if char == '"' or char == "'":
                # Start of string or char literal
                in_string = True
                quote_char = char
                output.append(char)
            elif char in ';{}':
                output.append(char)
                # IOCCC Rule 2b: These chars count as 0 if followed by whitespace.
                # If we are at EOF or next char is not whitespace, insert a space.
                if i + 1 >= length or not program[i+1].isspace():
                    output.append(' ')
            else:
                output.append(char)
        
        i += 1

    return "".join(output)

def squash_sequences(prog):
    """
    squash character sequences into #defines
    """
    headers, prog = split_source(prog)
    headers = headers.split("\n")
    for name, string, define, insert in to_squash:
        print(f"Replacing '{string}' with '{name}'")
        prog = prog.replace(string, name+" ")
        headers.insert(insert, define)
    return "\n".join(headers) + prog

def move_to_makefile(prog):
    """
    Moves #includes and some #defines to the makefile
    """
    headers, code = split_source(prog)
    makefile = []
    new_headers = []
    for header in headers.split("\n"):
        m = re.search(r'^#include <(.*)>$', header)
        if m:
            makefile.append(f"-include {m.group(1)}")
            continue
        m = re.search(r'^#define (\w) (.*)$', header)
        if m:
            short_name, define = m.groups()
            long_name = inv_replacements[short_name]
            if long_name in to_move_to_makefile:
                makefile.append(f"-D{short_name}='{define.replace(", ",",")}'")
                continue
        new_headers.append(header)
        
    headers = "\n".join(new_headers)+"\n"
    return headers + code, " ".join(makefile)

def main():
    if len(sys.argv) != 3:
        print(f"Usage: python {sys.argv[0]} <input_file> <output_file>")
        sys.exit(1)
        
    input_path, output_path = sys.argv[1:]
    
    with open(input_path, 'r', encoding='utf-8') as f:
        prog = f.read()

    prog = decomment(prog)
    prog = hex_to_decimal(prog)    
    prog = replace(prog)
    prog = strip_whitespace(prog)
    prog = squash_sequences(prog)
    prog = strip_whitespace(prog)
    #compress_c_code(prog)
    prog = minimize_ioccc_score(prog)
    prog, makefile = move_to_makefile(prog)
    print(f"Add this to the makefile\n\n{makefile}\n\n")

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(prog)
        print(f"Successfully processed '{input_path}'. Output written to '{output_path}'.")

if __name__ == "__main__":
    main()
