"""

Update the external git repos present in $PROJECT_ROOT/externals

"""

from subprocess import run
from os import listdir, getenv
from os.path import isdir, join, exists
import asyncio

async def update_repo(repo_path: str):
    run("git pull", shell=True, cwd=repo_path, check=True)

async def main():
    project_root = getenv("PROJECT_ROOT")
    if not project_root:
        raise EnvironmentError("PROJECT_ROOT environment variable is not set.")
    
    externals_dir = join(project_root, "external")
    repos = [repo for repo in listdir(externals_dir)
             if isdir(join(externals_dir, repo)) and exists(join(externals_dir, repo, ".git"))]

    await asyncio.gather(*(update_repo(join(externals_dir, repo)) for repo in repos))

if __name__ == "__main__":
    asyncio.run(main())
