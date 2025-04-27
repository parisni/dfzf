#![feature(let_chains)]

use anyhow::{Context, Result};
use clap::Parser;
use i3ipc::reply::Node;
use i3ipc::I3Connection;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Change the name of the mark to set.
    #[arg(short, long)]
    mark: String,

    /// Change the name of the mark to set.
    #[arg(short, long)]
    con_id: i64,

    /// Print extra debugging information.
    #[arg(short, long)]
    append_ts: bool,

    /// Print extra debugging information.
    #[arg(short, long)]
    debug: bool,
}

fn main() -> Result<()> {
    let args = Args::parse();
    run(&args)
}

fn run(args: &Args) -> Result<()> {
    let mark = args.mark.clone();
    let con_id = args.con_id;
    let append_ts = args.append_ts;
    let debug = args.debug;

    // Setup the IPC connect to i3. We'll use this to get the current i3 tree,
    // to find the currently focused window's ID.
    if debug {
        println!("Creating connnection mark:{}, con_id:{}", mark, con_id);
    }
    let mut connection =
        I3Connection::connect().with_context(|| "Could not connect to i3 (IPC)")?;

    let tree = connection
        .get_tree()
        .with_context(|| "Could not get i3's tree")?;
    let given_node = find_given_id(tree, con_id);
    if let Some(given_node) = given_node {
        if debug {
            println!(
                "Window {0} has marks:{1}",
                given_node.id,
                given_node.marks.join(", ")
            );
        }
        let mut found_any = false;
        for given_mark in given_node.marks.iter().filter(|m| m.starts_with(&mark)) {
            found_any = true;
            connection
                .run_command(&format!("unmark {}", given_mark))
                .with_context(|| format!("Could not unset i3 mark {}", given_mark))?;
            if debug {
                println!(
                    "removing {0} to window {1}",
                    given_mark,
                    given_node.id,
                );
            }
        }
        if !found_any {
            let add_mark = if append_ts {
                format!("{}-{}", mark, chrono::Local::now().timestamp())
            } else {
                mark
            };
            if debug {
                println!(
                    "Adding {0} to window {1}",
                    add_mark,
                    given_node.id,
                );
            }
            connection
                .run_command(&format!("[con_id={}] mark --add {}", con_id, add_mark))
                .with_context(|| format!("Could not set i3 mark {} to {}", con_id, add_mark))?;
        }
    }

    // Unreachable
    Ok(())
}

fn find_given_id(node: Node, con_id: i64) -> Option<Node> {
    if node.id == con_id {
        return Some(node);
    }

    for child in node.nodes.into_iter().chain(node.floating_nodes) {
        if let Some(found) = find_given_id(child, con_id) {
            return Some(found);
        }
    }

    None
}
