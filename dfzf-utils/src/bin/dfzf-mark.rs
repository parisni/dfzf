#![feature(let_chains)]

use anyhow::{Context, Result};
use clap::Parser;
use i3ipc::I3Connection;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Change the name of the mark to set.
    #[arg(short, long)]
    mark: String,

    /// Change the name of the mark to set.
    #[arg(short, long)]
    con_id: String,

    /// Change the name of the action [add, delete]
    #[arg(short, long)]
    action: String,

    /// Print extra debugging information.
    #[arg(short, long)]
    debug: bool,
}

fn main() -> Result<()> {
    let args = Args::parse();
    run(&args)
}

fn run(args: &Args) -> Result<()> {
    let debug = args.debug;
    let mark = args.mark.clone();
    let action = args.action.clone();
    let con_id = args.con_id.clone();


    // Setup the IPC connect to i3. We'll use this to get the current i3 tree,
    // to find the currently focused window's ID.
    if debug {
        println!("Creating connnection mark:{}, con_id:{}", mark, con_id);
    }
    let mut connection =
        I3Connection::connect().with_context(|| "Could not connect to i3 (IPC)")?;

    if action == "mark" {
    connection
        .run_command(&format!("[con_id={}] mark --add {}", con_id, mark))
        .with_context(|| format!("Could not set i3 mark {} to {}", con_id, mark))?;
    } else {
    connection
        .run_command(&format!("unmark {}", mark))
        .with_context(|| format!("Could not unset i3 mark {}", mark))?;
    }

    // Unreachable
    Ok(())
}

