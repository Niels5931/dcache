#!/usr/bin/env python3

from subprocess import run
from argparse import ArgumentParser
from os import getenv


def parser():
    parse = ArgumentParser()
    parse.add_argument("repo_name", help="Name of github repo to be cloned")
    return parse.parse_args()


def dependency(repo_name) -> None:
    run(
        f"git clone git@github.com:Niels5931/{repo_name} external/{repo_name}",
        cwd=getenv("PROJECT_ROOT"),
        shell=True,
    )


def main():
    args = parser()
    run("mkdir -p external", shell=True)
    dependency(args.repo_name)


if __name__ == "__main__":
    main()
