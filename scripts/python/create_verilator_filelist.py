#!/usr/bin/env python3

import sys
import os
import datetime

def parse_yaml_structure(yaml_path, visited=None):
    """
    Parses the YAML configuration recursively to gather files grouped by core.
    
    Args:
        yaml_path (str): Path to the YAML configuration file.
        visited (set): Set of visited file paths to prevent infinite loops.
        
    Returns:
        list: A list of tuples, where each tuple contains (core_name, [file_paths]).
    """
    if visited is None:
        visited = set()
    
    yaml_path = os.path.abspath(yaml_path)
    if yaml_path in visited:
        return []
    visited.add(yaml_path)
    
    if not os.path.exists(yaml_path):
        print(f"Error: {yaml_path} not found")
        return []

    config_dir = os.path.dirname(yaml_path)
    
    try:
        with open(yaml_path, 'r') as f:
            lines = f.readlines()
    except Exception as e:
        print(f"Error reading {yaml_path}: {e}")
        return []
        
    # Extract core name from YAML or fallback to directory name
    core_name = os.path.basename(config_dir)
    for line in lines:
        if line.strip().startswith("name:"):
            core_name = line.strip().replace("name:", "").strip()
            break
            
    ordered_blocks = [] 
    
    # Parse dependencies
    dep_idx = next((i for i, line in enumerate(lines) if line.strip().startswith("dependencies:")), None)
    if dep_idx is not None:
        for line in lines[dep_idx+1:]:
            sline = line.strip()
            if sline.startswith("-"):
                dep_rel = sline.replace("- ", "")
                dep_path = os.path.normpath(os.path.join(config_dir, dep_rel))
                ordered_blocks.extend(parse_yaml_structure(dep_path, visited))
            elif not sline:
                continue
            else:
                break
                
    # Parse files
    files_idx = next((i for i, line in enumerate(lines) if line.strip().startswith("files:")), None)
    current_core_files = []
    if files_idx is not None:
        for line in lines[files_idx+1:]:
            sline = line.strip()
            if sline.startswith("-"):
                file_rel = sline.replace("- ", "")
                file_path = os.path.normpath(os.path.join(config_dir, file_rel))
                current_core_files.append(file_path)
            elif not sline:
                continue
            else:
                break
                
    if current_core_files:
        ordered_blocks.append((core_name, current_core_files))
        
    return ordered_blocks

def main():
    if len(sys.argv) < 2:
        print("Usage: create_verilator_filelist.py <core_name>")
        sys.exit(1)

    core_name = sys.argv[1]
    project_root = os.getenv("PROJECT_ROOT", os.getcwd())
    
    # Path to the core's yaml
    yaml_path = os.path.join(project_root, "cores", core_name, f"{core_name}.yml")
    
    if not os.path.exists(yaml_path):
        # Try finding it relative to project root if absolute path failed
        yaml_path = os.path.abspath(f"cores/{core_name}/{core_name}.yml")
        if not os.path.exists(yaml_path):
            print(f"Error: Configuration file {yaml_path} not found.")
            sys.exit(1)

    # Get structured file list
    blocks = parse_yaml_structure(yaml_path)
    
    # Simulation file (testbench)
    sim_file = os.path.join(project_root, "cores", core_name, "sim", f"{core_name}_tb.sv")
    if not os.path.exists(sim_file):
        sim_file = os.path.abspath(f"cores/{core_name}/sim/{core_name}_tb.sv")
    
    if os.path.exists(sim_file):
        blocks.append((f"{core_name} (Simulation)", [sim_file]))
    else:
        print(f"Warning: Simulation file {sim_file} not found.")

    # Output file path: cores/<core_name>/sim/verilator_files.f
    sim_dir = os.path.join(project_root, "cores", core_name, "sim")
    if not os.path.exists(sim_dir):
        sim_dir = os.path.abspath(f"cores/{core_name}/sim")
        
    os.makedirs(sim_dir, exist_ok=True)
    output_file = os.path.join(sim_dir, "verilator_files.f")
    
    # Write with deduplication while preserving order
    seen_files = set()
    
    with open(output_file, 'w') as f:
        # Header
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        f.write(f"// Auto-generated Verilator file list for target: {core_name}\n")
        f.write(f"// Generated at: {timestamp}\n\n")
        
        for name, files in blocks:
            # Check if there are any new files in this block
            new_files = [fp for fp in files if fp not in seen_files]
            
            if new_files:
                f.write(f"// Core: {name}\n")
                for fp in new_files:
                    f.write(f"{fp}\n")
                    seen_files.add(fp)
                f.write("\n")
            
    print(f"Generated file list: {output_file}")

if __name__ == "__main__":
    main()
