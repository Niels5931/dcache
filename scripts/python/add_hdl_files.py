#!/usr/bin/env python3.9

from os import chdir, listdir, getcwd, getenv
from sys import argv
from scripts.python.file_parser import hdlFileParser

def main():
    project_name = argv[1].strip('/')
    #print(f"{getenv('PROJECT_ROOT')}/cores/{project_name}.yml")
    hdlFileParser.parse_files_from_config(f"{getenv('PROJECT_ROOT')}/cores/{project_name}/{project_name}.yml")
    #print(hdlFileParser.verilogFiles)
    #print(hdlFileParser.vhdlFiles)
    print(hdlFileParser.hdlFiles)

if __name__ == '__main__':
    main()