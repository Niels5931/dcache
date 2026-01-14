#!/usr/bin/env python3.9

from os import chdir, getcwd
from subprocess import run, STDOUT
from sys import argv

def build_project(project_name: str):
    run(['simpl vivado'],shell=True, cwd=f"{getcwd()}/{project_name}/syn")

def main():
    project_name = argv[1].replace("/", "")
    build_project(project_name)

if __name__ == '__main__':
    main()