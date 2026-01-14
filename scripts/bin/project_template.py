#!/usr/bin/env python3
from os import mkdir, chdir, getcwd, listdir, getenv, environ, makedirs
from subprocess import run
import argparse
from scripts.python.remove_project import rm_dir
from scripts.python.file_parser import hdlFileParser


def main():
    argparser = argparse.ArgumentParser(description="Create a new project template")
    argparser.add_argument("project_name", help="Name of the project")
    argparser.add_argument(
        "-d", "--dependencies", nargs="+", help="List of dependencies"
    )
    argparser.add_argument(
        "-t", help="File extension for the top-level file", default=".sv"
    )
    argparser.add_argument(
        "-x",
        "--external",
        dest="external",
        type=str,
        help="Git repo names. Will clone submodules from github.com/Niels5931/<git_repo>",
    )
    args = argparser.parse_args()

    if "cores" not in listdir(getcwd()):
        mkdir("cores")

    project_root = getenv("PROJECT_ROOT")
    # Get the name of the project from the command line
    project_name = args.project_name
    # check if the project directory exists
    if project_name in listdir(getcwd() + "/cores"):
        rm_dir(f"{getcwd()}/cores/{project_name}")
    # Create the project directory
    chdir(f"{project_root}/cores")
    mkdir(project_name)
    # create yml file
    chdir(project_name)
    with open(f"{getcwd()}/{project_name}.yml", "w") as f:
        f.write("#%SimplAPI=1.0\n\n")
        f.write(f"name: {project_name}\n")
        if args.dependencies:
            f.write(f"dependencies:\n")
            for dep in args.dependencies:
                f.write(f"- ../{dep}/{dep}.yml\n")
        if args.external:
            if not args.dependencies:
                f.write(f"dependencies:\n")
            chdir(getenv("PROJECT_ROOT"))
            makedirs("external", exist_ok=True)
            chdir("external")
            for repo in args.external.split(","):
                if repo in listdir(getcwd()):
                    continue
                run(f"git clone https://github.com/Niels5931/{repo}.git", shell=True)
            chdir(getenv("PROJECT_ROOT"))
            for repo in args.external.split(","):
                f.write(f"- ../../external/{repo}/cores/{repo}/{repo}.yml\n")
            chdir(f"{project_root}/cores/{project_name}")
        f.write("\n")
        f.write(f"files:\n- hdl/{project_name}{args.t}\n")
    # Create the project subdirectories
    mkdir("hdl")
    mkdir("sim")
    mkdir("syn")

    # make top level files in hdl and sim
    open(f"{getcwd()}/hdl/{project_name}{args.t}", "w")
    open(f"{getcwd()}/sim/{project_name}_tb{args.t}", "w")

    if args.dependencies:
        environ["PROJECT_NAME"] = project_name
        hdlFileParser.parse_deps_from_config(f"{getcwd()}/")

    # print(hdlFileParser.topHdlFiles)


if __name__ == "__main__":
    main()
