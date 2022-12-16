use std::collections::{HashMap, HashSet};
use std::io::BufRead;
use std::{env, io};
use std::fs::File;
use std::error::Error;
use std::fmt;

#[derive(Debug, Clone, PartialEq, Eq)]
struct Valve {
    name: String,
    flow: i64,
    connected: Vec<String>
}

impl Valve {
    fn optimize(&self, mapping: &HashMap<String, Valve>, i: usize, opened: HashSet<String>) -> usize {
        let mut res = 0;

        let mut new_i = i;

        let mut new_opened = opened.clone();

        if !new_opened.contains(&self.name.clone()) {
            new_i += 1;
            new_opened.insert(self.name.clone());
        }

        if new_i < 30 {
            for ch in &self.connected {
                res += mapping.get(ch).expect("wtf").optimize(mapping, new_i + 1, new_opened.clone());
            }
        } else {
            res = 1;
        }

        res
    }
}

impl fmt::Display for Valve {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "Valve {} has flow rate={}; tunnel{} lead{} to valve{} {}",
            self.name, self.flow,
            if self.connected.len() == 1 { "" } else { "s" },
            if self.connected.len() == 1 { "s" } else { "" },
            if self.connected.len() == 1 { "" } else { "s" },
            self.connected.join(", "))
    }
}

fn main() -> Result<(), Box<dyn Error>> {
    let args: Vec<String> = env::args().collect();

    if args.len() != 2 {
        println!("No input file provided");
        std::process::exit(1);
    }

    let infile = File::open(&args[1])?;
    let reader = io::BufReader::new(infile).lines();

    let mut valves = HashMap::new();

    for line in reader {
        if let Ok(line) = line {
            let desc = line.split("; ").collect::<Vec<_>>();
            
            let mut flow = 0;

            for ch in desc[0].as_bytes().get(23..).unwrap() {
                match ch {
                    b'0'..=b'9' => {
                        flow = (flow * 10) + i64::from(ch - b'0');
                    },
                    _ => break
                }
            }

            let mut cur = Valve {
                name: String::from(desc[0].get(6..8).unwrap()),
                flow,
                connected: Vec::new()
            };

            let mut slice = desc[1].get(22..).unwrap();

            if slice.get(0..1).unwrap() == " " {
                slice = slice.get(1..).unwrap();
            }

            for v in slice.split(", ") {
                cur.connected.push(String::from(v));
            }

            valves.insert(cur.name.clone(), cur);
        }
    }

    let start = valves.get("AA").expect("help");

    let opened = HashSet::new();
    let states = start.optimize(&valves, 0, opened);

    println!("{states}");

    Ok(())
}
