#!/usr/bin/env python3.9

from os import getenv
from sys import argv

def main():
    work_dir = f"{getenv('PROJECT_ROOT')}/cores/{argv[1]}"
    # read the top hdl file
    top_file = open(f"{work_dir}/hdl/{argv[1]}.vhd", 'r').readlines()
    # get port list
    generic_start = top_file.index("generic (\n")
    generic_end = top_file.index(");\n")
    ports_start = top_file.index("port (\n")
    ports_end = [i for i in enumerate(top_file) if i[1] == ");\n"][1][0]
    # get the port list
    ports = top_file[ports_start+1:ports_end]
    # get the generic list
    generics = top_file[generic_start+1:generic_end]

    with open (f"{work_dir}/sim/{argv[1]}_tb.vhd", 'w') as f:
        f.write(f"library ieee;\n")
        f.write(f"use ieee.std_logic_1164.all;\n")
        f.write(f"use ieee.numeric_std.all;\n\n")
        f.write(f"entity {argv[1]}_tb is\n")
        f.write(f"end entity;\n\n")
        f.write(f"architecture rtl of {argv[1]}_tb is\n")
        f.write(f"component {argv[1]} is\n")
        f.write(f"generic (\n")
        for g in generics:
            f.write(f"\t{g}")
        f.write(f");\n")
        f.write(f"port (\n")
        for p in ports:
            f.write(f"\t{p}")
        f.write(f");\n")
        f.write(f"end component;\n\n")

if __name__ == "__main__":
    main()
            

