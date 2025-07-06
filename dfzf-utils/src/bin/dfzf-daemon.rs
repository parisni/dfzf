use std::thread;
use std::time::Duration;

use anyhow::{Context, Result};
use clap::Parser;
use i3ipc::reply::Node;
use i3ipc::I3Connection;
use i3ipc::I3EventListener;
use i3ipc::Subscription;
use chrono::Local;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Print extra debugging information.
    #[arg(short, long)]
    debug: bool,
}

fn main() -> Result<()> {
    let args = Args::parse();

    loop {
        if let Err(err) = run(&args) {
            eprintln!("Error: {:?}", err)
        }

        eprintln!("\nRestarting in 0.5s");
        thread::sleep(Duration::from_millis(500));
        eprintln!();
    }
}

fn run(args: &Args) -> Result<()> {
    let debug = args.debug;

    if debug {
        println!("Starting i3 event listener");
    }

    // Setup listener for i3 events. We'll be listening for window events.
    // This event is triggered whenever the focus changes.
    let mut listener =
        I3EventListener::connect().with_context(|| "Could not connect to i3 (event listener)")?;
    listener
        .subscribe(&[Subscription::Window])
        .with_context(|| "Could not subscribe to i3 events")?;

    // Setup the IPC connect to i3. We'll use this to get the current i3 tree,
    // to find the currently focused window's ID.
    let mut connection =
        I3Connection::connect().with_context(|| "Could not connect to i3 (IPC)")?;

    // Get the intial focused window
    let tree = connection
        .get_tree()
        .with_context(|| "Could not get i3's tree")?;
    let mut last_focused_node = find_focused_id(tree);

    // Start listening for i3 events
    for event in listener.listen() {
        event.with_context(|| "Could not receive i3 event. This is normal when restarting i3")?;

        let tree = connection
            .get_tree()
            .with_context(|| "Could not get i3's tree")?;
        let focused_node = find_focused_id(tree);

        if let Some(focused_node) = focused_node {
            if let Some(ref last_focused_node) = last_focused_node && focused_node.id == last_focused_node.id {
                // Ignore if focused window ID hasn't changed
                continue;
            }
            if focused_node.marks.iter().any(|mark| mark == "_dfzf-preview") {
                // Ignore the refresh of the sort mark
                if debug {
                    println!("Ignoring the refresh of sort mark on {0}", focused_node.id)
                }
                last_focused_node = Some(focused_node);
                continue;
            }

            if let Some(last_focused_node) = last_focused_node {
                if debug {
                    println!("Saving window ID {0}. Current window ID is {1}",last_focused_node.id, focused_node.id)
                }

                // Save the new last focused ID as kark
                for mark in focused_node
                    .marks
                    .iter()
                    .filter(|m| m.starts_with("_dfzf-sort"))
                {

                    if debug {
                        println!("Dropping mark {0} on window {1} among {2}", mark, focused_node.id, focused_node.marks.join(", "))
                    }
                    connection
                        .run_command(&format!("unmark {}", mark))
                        .with_context(|| format!("Could not unset i3 mark {}", mark))?;
                }
                let timestamp = Local::now().timestamp_millis();
                let mark = format!("_dfzf-sort-{timestamp}");
                connection
                    .run_command(&format!("[con_id={}] mark --add {}", focused_node.id, mark))
                    .with_context(|| format!("Could not set i3 mark {} to {}", mark, last_focused_node.id))?;
            }

            last_focused_node = Some(focused_node);
        }
    }

    // Unreachable
    Ok(())
}

/// Traverses i3 tree to find which node (including floating) is focused.
fn find_focused_id(mut node: Node) -> Option<Node> {
    while !node.focused {
        let focused_id = node.focus.first().cloned()?;
        node = node
            .nodes
            .into_iter()
            .chain(node.floating_nodes)
            .find(|n| n.id == focused_id)?;
    }
    Some(node)
}
