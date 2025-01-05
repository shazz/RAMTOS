import argparse
import json
from capstone import *
from shared import non_reloc_tables, tos_versions


known_addresses = set([item for sublist in non_reloc_tables.values() for item in sublist])

def disassemble(target_tos_version: str, country: str, tos_path: str):

    target = tos_versions[target_tos_version]
    v_str = target_tos_version.replace(".", "")
    version = f"TOS{v_str}{country.upper()}"
    path = f"{tos_path}/{version}.IMG"

    md = Cs(CS_ARCH_M68K, CS_MODE_M68K_000)
    md.detail = True
    md.skipdata = True
    md.skipdata_setup = ("dc.b", None, None)

    non_reloc_adresses = set()
    non_reloc_adresses_with_desc = []
    branches = ["bcs.w", "beq.w", "bra.w", "bsr.w", "bne.w"]

    print(f"Loading {path}")
    with open(path, "rb") as f:
        binary_code = f.read()

        with open(f"tmp/{version}.ls", "w") as f_full:
            for i in md.disasm(binary_code, target["start_address"]):
                address = hex(i.address).split("0x")[1]

                # print(f"${address:<5}        {i.mnemonic:<7}    {i.op_str:<40}")

                instruction = i.bytes.hex()
                last_word = f"{i.bytes.hex()[-4:]}"

                addr = i.address - target["start_address"]
                # addr = (i.address & 0xfffff) if v_str == "206" else (i.address & 0xffff)
                f_full.write(f"${address:<6} {hex(addr).replace("0x","$"):<5} {i.bytes.hex():<30} {i.mnemonic:<7}    {i.op_str:<50}; {i.size}\n")

                for searched_offset in target["offsets"]:

                    if len(instruction) > 6 and last_word == f"00{searched_offset}":
                        addr = addr + (len(instruction)//2) - 2
                        new = "[new!]" if addr not in known_addresses else "[known in some TOS]"

                        address = hex(addr).replace("0x", "$")
                        if ((f"${searched_offset}" in i.op_str) and 
                            (f"${searched_offset}(" not in i.op_str) and 
                            ("(pc)" not in i.op_str) and 
                            all(a not in (i.op_str) for a in target["skipped_addresses"]) and
                            all(a not in (i.op_str) for a in target["skipped_addressing"]) and
                            (i.mnemonic.split('.')[0] not in target["skipped_mnemonics"])) or (i.mnemonic in branches):
                            # print(f"{address} {i.mnemonic}  {i.op_str} {i.mnemonic in target['skipped_mnemonics']} \'{i.mnemonic}\' in {target['skipped_mnemonics']}")
                            # print(f"{address} {i.mnemonic}  {i.op_str} => ", end=' ')
                            # for op in i.operands:
                            #     print(f"type: {op.type} mode: {op.address_mode}", end=' ')
                            # print("")
                            non_reloc_adresses.add(addr)
                            non_reloc_adresses_with_desc.append(f"{address:<16}    ; {i.mnemonic}  {i.op_str} {new}")
                        
                        elif i.mnemonic.split('.')[0] in target["skipped_mnemonics"]:
                            print(f"{address:<16} {i.mnemonic}  {i.op_str} => skipped mnemonic")

                        elif any(a in (i.op_str) for a in target["skipped_addresses"]):
                            print(f"{address:<16} {i.mnemonic}  {i.op_str} => skipped address")                              

                        elif f"${searched_offset}(" not in i.op_str:
                            if f"{i.mnemonic}  {i.op_str}" == "movem.l  (a7)+, d5-d7":
                                non_reloc_adresses.add(addr)
                                non_reloc_adresses_with_desc.append(f"{address:<16}    ; {i.mnemonic}  {i.op_str} {new}")
                            else:
                                print(f"{address:<16} {i.mnemonic}  {i.op_str} => ?")


        # compare with existing tables
        results_stats = {}
        for tos, addresses in non_reloc_tables.items():

            if v_str not in tos:
                print(f"Skipping comparison with {tos}")
                continue

            missing_addresses = []
            common_addresses = []
            not_found_addresses = []
            print(f"Comparing with non-reloc table for {tos}")
            for address in non_reloc_adresses:
                if address not in addresses:
                    missing_addresses.append(address)
                else:
                    common_addresses.append(address)
            for address in addresses:
                if address not in non_reloc_adresses:
                    not_found_addresses.append(address)

            results_stats[tos] ={
                "nb_missing": len(missing_addresses),
                "missing_addresses": [hex(a) for a in sorted(missing_addresses)],
                "nb_common": len(common_addresses),
                "common_addresses": [hex(a) for a in sorted(common_addresses)],
                "nb_not_found": len(not_found_addresses),
                "not_found_addresses": [hex(a) for a in sorted(not_found_addresses)],
            }

        with open(f"tmp/{version}.json", "w") as f:
            json.dump(results_stats, f, indent=4)

        with open(f"tmp/{version}.adr", "w") as f:
            results = [f"    dc.l    {a}\n" for a in non_reloc_adresses_with_desc]
            f.writelines(results)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--tos-version", choices=list(tos_versions.keys()), help="tos version", default="2.06")
    parser.add_argument("--country", choices=["fr", "de", "us", "uk", "sw", "x"], help="country", default="fr")
    parser.add_argument("--images-dir", help="TOS directory", default="TOS", required=False)
    args = parser.parse_args()

    country = args.country
    target_tos_version = args.tos_version
    tos_path = args.images_dir

    disassemble(target_tos_version=target_tos_version, country=country, tos_path=tos_path)
