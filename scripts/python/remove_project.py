#!/usr/bin/env python3.9

from os import listdir, remove, rmdir, getcwd
from sys import argv

def rm_dir(dir):
    for f in listdir(dir):
        try:
            remove(f"{dir}/{f}")
        except:
            rm_dir(f"{dir}/{f}")
    rmdir(dir)

def main():
    # Get the name of the project from the command line
    project_name = argv[1].replace("/", "")
    # check if the project directory exists
    if project_name not in listdir(getcwd()):
        print(f"Project {project_name} does not exist")
        exit(1)
    rm_dir(f"{getcwd()}/{project_name}")

if __name__ == '__main__':
    main()


    

