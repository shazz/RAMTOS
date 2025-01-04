import argparse
import json
from capstone import *

tos_versions = {
    "1.00": {
        "start_address": 0xfc0000,
        "offsets": ["fe", "fd", "fc"],
        "skipped_mnemonics": []
    },
    "1.02": {
        "start_address": 0xfc0000,
        "offsets": ["fe", "fd", "fc"],
        "skipped_mnemonics": []
    },
    "1.04": {
        "start_address": 0xfc0000,
        "offsets": ["fe", "fd", "fc"],
        "skipped_mnemonics": ["dbvc", "dbeq", "sbcd", "addi", "eori", "ori", "cmpi", "bset", "btst", "negx", "bclr", "roxl", "eor", "muls", "mulu", "divu", "divs", "sgt", "cmp", "addq", "bchg", "adda", "or", "dbge", "subq"],
        "skipped_addresses": ["$fe.w", "$fd.w"],
        "skipped_addressing": ["d0.w", "d1.w", "d2.w", "d3.w", "d4.w", "d5.w", "d6.w", "d7.w"]
    },
    "1.06": {
        "start_address": 0xfc0000,
        "offsets": ["fe", "fd", "fc"],
        "skipped_mnemonics": []
    },
    "1.62": {
        "start_address": 0xfc0000,
        "offsets": ["fe", "fd", "fc"],
        "skipped_mnemonics": []
    },
    "2.05": {
        "start_address": 0xe00000,
        "offsets": ["e0", "e2"],
        "skipped_mnemonics": []
    },
    "2.06": {
        "start_address": 0xe00000,
        "offsets": ["e0", "e2"],
        "skipped_mnemonics": []
    }
}

non_reloc_tables = {
    "TOS104UK": set([0x117e, 0x1514, 0x3bac, 0x3e04, 0x3eb2, 0x55ae, 0x610c, 0x8594, 0x88b4, 0x15c1c, 0x170d4, 0x17426, 0x18406, 0x1abc2, 0x251e8, 0x27298, 0x28898, 0x29644, 0x29780, 0x29b20, 0x29cd6, 0x2a580, 0x2a680]),
    "TOS104DE": set([0x117e, 0x1514, 0x3a4c, 0x3f0c, 0x5608, 0x6166, 0x85ee, 0x890e, 0x15c76, 0x1712e, 0x17480, 0x18438, 0x1abf4, 0x2521a, 0x272ca, 0x288ca, 0x29676, 0x297b2, 0x29b52, 0x29d08, 0x2a5b2, 0x2a6b2, 0x2ec00]),
    "TOS206SW": set([0x89a, 0x13d0, 0x1bca, 0x1d3a, 0x1d3e, 0x1df0, 0x1df6, 0x229c, 0x624a, 0x6bee, 0x8dc6, 0x8de8, 0x106de, 0x13334, 0x1585e, 0x17b68, 0x18c7a, 0x1911a, 0x19292, 0x19d82, 0x1a988, 0x1b262, 0x1c41a, 0x1ca82, 0x1cce8, 0x1cdb6, 0x1cfdc, 0x1d848, 0x20872, 0x2122e, 0x22bfa, 0x22c16, 0x2418c, 0x265d6, 0x266c4, 0x27266, 0x2aa2a, 0x2b060, 0x2b824, 0x2b850, 0x32860, 0x335b6, 0x351de, 0x3a364, 0x3a4fe, 0x3a68c, 0x3a690, 0x3b750]),
    "TOS206UK": set([0x89a, 0x13d0, 0x1bca, 0x1d3a, 0x1d3e, 0x1df0, 0x1df6, 0x229c, 0x61d2, 0x6b76, 0x8d4e, 0x8d70, 0x10666, 0x132bc, 0x157e6, 0x17af0, 0x18c02, 0x190a2, 0x1921a, 0x19d0a, 0x1a910, 0x1b1ea, 0x1c3a2, 0x1ca0a, 0x1cc70, 0x1cd3e, 0x1cf64, 0x1d7d0, 0x207fa, 0x211b6, 0x22b82, 0x22b9e, 0x24114, 0x264b6, 0x26590, 0x265b8, 0x271ee, 0x2a9b2, 0x2afe8, 0x2b7ac, 0x2b7d8, 0x32812, 0x33568, 0x35190, 0x3a0a0 , 0x3a23a, 0x3a3c8, 0x3a3cc]),
    "TOS206DE": set([0x89a, 0x13d0, 0x1bca, 0x1d3a, 0x1d3e, 0x1df0, 0x1df6, 0x229c, 0x622c, 0x6bd0, 0x8da8, 0x8dca, 0x106c0, 0x13316, 0x15840, 0x17b4a, 0x18c5c, 0x190fc, 0x19274, 0x19d64, 0x1a96a, 0x1b244, 0x1c3fc, 0x1ca64, 0x1ccca, 0x1cd98, 0x1cfbe, 0x1d82a, 0x20854, 0x21210, 0x22bdc, 0x22bf8, 0x2416e, 0x265b8, 0x266a6, 0x27248, 0x2aa0c, 0x2b042, 0x2b802, 0x2b82a, 0x2ba18, 0x32842, 0x33598, 0x351c0, 0x3a2e2, 0x3a47c, 0x3a60a, 0x3a60e, 0x3b6ce]),
    "TOS206X": set([0x89a, 0x13d0, 0x1bca, 0x1d3a, 0x1d3e, 0x1df0, 0x1df6, 0x229c, 0x61d2, 0x6b76, 0x8d4e, 0x8d70, 0x10666, 0x132bc, 0x157e6, 0x17af0, 0x18c02, 0x190a2, 0x1921a, 0x19d0a, 0x1a910, 0x1b1ea, 0x1c3a2, 0x1ca0a, 0x1cc70, 0x1cd3e, 0x1cf64, 0x1e1aa, 0x1e956, 0x207fa, 0x211b6, 0x22b82, 0x22b9e, 0x24114, 0x264b6, 0x26590, 0x265b8, 0x271ee, 0x2afe8, 0x2b7ac, 0x2b7d8, 0x32812, 0x33568, 0x35190, 0x3a0a0, 0x3a23a, 0x3a3c8, 0x3a3cc, ])
}
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
                f_full.write(f"${address:<6} {hex(addr).replace("0x","$"):<5} {i.bytes.hex():<20} {i.mnemonic:<7}    {i.op_str:<40}; {i.size}\n")

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
