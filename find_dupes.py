
import re

def find_duplicates(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    ar_section = False
    en_section = False
    ar_keys = {}
    en_keys = {}
    
    for i, line in enumerate(lines):
        line_num = i + 1
        if "'ar': {" in line:
            ar_section = True
            en_section = False
            continue
        if "'en': {" in line:
            ar_section = False
            en_section = True
            continue
        
        match = re.search(r"'(\w+)':", line)
        if match:
            key = match.group(1)
            if ar_section:
                if key in ar_keys:
                    print(f"Arabic duplicate: '{key}' at line {line_num} (first seen at line {ar_keys[key]})")
                else:
                    ar_keys[key] = line_num
            elif en_section:
                if key in en_keys:
                    print(f"English duplicate: '{key}' at line {line_num} (first seen at line {en_keys[key]})")
                else:
                    en_keys[key] = line_num

if __name__ == "__main__":
    find_duplicates(r"d:\new\mtzhr\lib\services\translations.dart")
