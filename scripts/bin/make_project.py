<<<<<<< HEAD
#!./_env/bin/python3
=======
#!/usr/bin/env python3
>>>>>>> temp/main

from os import chdir, listdir, getcwd, getenv
from sys import argv
from subprocess import run
from scripts.python.file_parser import hdlFileParser

def main():
    work_dir = f"{getenv('PROJECT_ROOT')}/cores/{argv[1]}"
    # get files to include
    hdlFileParser.parse_files_from_config(f"{work_dir}/{argv[1]}.yml")
    print(hdlFileParser.hdlFiles)
    chdir(f"{work_dir}")
    run(["mkdir", "-p", "_project"])
    chdir(f"{work_dir}/_project")
    vhdl_2008 = False
    with open("project.tcl", 'w') as f:
        f.write("create_project -force -name project\n")
        for file in hdlFileParser.hdlFiles:
            f.write(f"add_files \"{file.path}\"\n")
            if file.file_type == "vhdl":
                vhdl_2008 = True
        f.write(f"set_property top {argv[1]} [current_fileset]\n")
        f.write(f"add_files -fileset sim_1 \"{work_dir}/sim/{argv[1]}_tb.sv\"\n") 
        f.write("update_compile_order -fileset sources_1\n")
        if vhdl_2008:
            f.write("set_property FILE_TYPE {VHDL 2008} [get_files *.vhd]\n")
        f.write("exit\n")
    

if __name__ == "__main__":
    main()