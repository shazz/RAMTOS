from capstone import *

def disassemble(version: str, path: str, start_address: int = 0xfc0000):

    md = Cs(CS_ARCH_M68K, CS_MODE_M68K_000)
    md.detail = True
    md.skipdata = True
    md.skipdata_setup = ("dc.b", None, None)

    non_reloc_adresses = []
    branches = ["bcs.w", "beq.w", "bra.w"]

    with open(path, "rb") as f:
        binary_code = f.read()

        with open(f"{version}.ls", "w") as f_full:
            for i in md.disasm(binary_code, start_address):
                address = hex(i.address).split("0x")[1]

                # print(f"${address:<5}        {i.mnemonic:<7}    {i.op_str:<40}")
                f_full.write(f"${address:<5} {i.bytes.hex():<16} {i.mnemonic:<7}    {i.op_str:<40}; {i.size}\n")

                instruction = i.bytes.hex()              
                last_word = f"{i.bytes.hex()[-4:]}"

                if len(instruction) > 6 and last_word == "00e0":
                    address = hex((i.address & 0xfffff) + 2).replace("0x", "$")
                    if ("$e0" in i.op_str and "$e0(" not in i.op_str and "(pc)" not in i.op_str) or (i.mnemonic in branches):
                        # print(f"{address} {i.mnemonic}  {i.op_str} => ", end=' ')
                        # for op in i.operands:
                        #     print(f"type: {op.type} mode: {op.address_mode}", end=' ')
                        # print("")
                        non_reloc_adresses.append(f"{address:<16}    ; {i.mnemonic}  {i.op_str}")
                    elif "$e0(" not in i.op_str:
                        print(f"{address:<16} {i.mnemonic}  {i.op_str} => ")

                if len(instruction) > 6 and last_word == "00e2":
                    address = hex((i.address & 0xfffff) + 2).replace("0x", "$")
                    if ("$e2" in i.op_str and "$e2(" not in i.op_str and "(pc)" not in i.op_str) or (i.mnemonic in branches):
                        # print(f"{address} {i.mnemonic}  {i.op_str} => ", end=' ')
                        # for op in i.operands:
                        #     print(f"type: {op.type} mode: {op.address_mode}", end=' ')
                        # print("")
                        non_reloc_adresses.append(f"{address:<16}    ; {i.mnemonic}  {i.op_str}")
                    elif "$e2(" not in i.op_str:
                        print(f"{address:<16} {i.mnemonic}  {i.op_str} => ")

        with open(f"{version}.adr", "w") as f:
            f.write('\n    dc.l    '.join(non_reloc_adresses))

if __name__ == "__main__":
    disassemble("TOS206FR", "TOS206FR.IMG", start_address=0xE00000)
