import argparse
import json
from typing import List
from shared import non_reloc_tables, tos_versions

def find_address(addr: int, listing: List[str], instructions_range):
    # print(f"Searching address: {addr} in listing")
    for idx, line in enumerate(listing):
        if addr in line:
            return listing[idx:idx+instructions_range+1]
    
    raise LookupError()

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--tos-version", choices=list(tos_versions.keys()), help="tos version", default="1.04")
    parser.add_argument("--source-country", choices=["fr", "de", "us", "uk", "sw", "x"], help="country", default="de")
    parser.add_argument("--target-country", choices=["fr", "de", "us", "uk", "sw", "x", "es", "nl"], help="country", default="fr")

    args = parser.parse_args()
    source_country = args.source_country
    target_country = args.target_country
    target_tos_version = args.tos_version
    source_tos_id = f"TOS{target_tos_version.replace(".", "")}{source_country.upper()}"
    target_tos_id = f"TOS{target_tos_version.replace(".", "")}{target_country.upper()}"

    print(f"Loading benchmark TOS: {source_tos_id}")
    with open(f"tmp/{source_tos_id}.ls") as f:
        source_disassembly = f.readlines() #[line.strip() for line in f.readlines()]

    print(f"Loading target TOS: {target_tos_id}")
    with open(f"tmp/{target_tos_id}.ls") as f:
        target_disassembly = f.readlines()

    addresses = non_reloc_tables[source_tos_id]
    total_addresses_matches = {}

    for instructions_range in range(6, 0, -1): 

        patterns = {}
        pattern_offsets = {}
        for address in addresses:

            if address in total_addresses_matches and total_addresses_matches[address] is not None:
                # print(f"Skipping {hex(address)}")
                continue
            
            addr = f"{hex(address).replace('0x', '$')} "

            try:
                patterns[address] = find_address(addr=addr, listing=source_disassembly, instructions_range=instructions_range)
                pattern_offsets[address] = 0
            except LookupError:
                try:
                    addr = f"{hex(address+2).replace('0x', '$')} "
                    patterns[address] = find_address(addr=addr, listing=source_disassembly, instructions_range=instructions_range)
                    pattern_offsets[address] = 2
                except LookupError:
                    addr = f"{hex(address+4).replace('0x', '$')} "
                    patterns[address] = find_address(addr=addr, listing=source_disassembly, instructions_range=instructions_range) 
                    pattern_offsets[address] = 4

        # for address, pattern in patterns.items():
        #     print(f"address: {hex(address)}")
        #     for line in pattern:
        #         print(f"    |{line[45:106].strip()}")

        addresses_matches = {}
        for address, pattern in patterns.items():

            addresses_matches[address] = None
            # print(f"Matching address: {hex(address)}")
                
            for idx in range(len(target_disassembly)-(instructions_range)):
                found = False
                for i in range(instructions_range+1):
                    if pattern[i][45:106].strip() in target_disassembly[idx+i]:
                        found = True
                    else:
                        found = False
                        break

                if found:

                    target_address = int(target_disassembly[idx][8:14].strip().replace("$", "0x"), 16)
                    addresses_matches[address] = target_address - pattern_offsets[address]
                    idx += 6

                    print(f"Found equivalent of {hex(address)} at {hex(target_address - pattern_offsets[address])}")
                    for line in pattern:
                        print(f"    |{line[0:106].strip()}")
                    print("with")
                    for m_idx in range(instructions_range+1):
                        print(f"    |{target_disassembly[idx+m_idx][0:106].strip()}")

        print(f"intermediate matches: {sum(1 for value in addresses_matches.values() if value is not None)} / {len(addresses_matches)} with range: {instructions_range}")
        total_addresses_matches |= addresses_matches

    total_addresses_matches = dict(sorted(total_addresses_matches.items()))
    for address, match in total_addresses_matches.items():
        print(f"{hex(address).replace("0x", "$")}: {hex(match).replace("0x", "$") if match is not None else None}")
    print(f"matches: {sum(1 for value in total_addresses_matches.values() if value is not None)} / {len(total_addresses_matches)}")
        

    
