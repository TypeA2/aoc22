use std::io::BufRead;
use std::{env, io};
use std::fs::File;
use std::error::Error;
use std::fmt;
use std::hash::Hash;

#[derive(Copy, Clone, PartialEq, Eq, Hash, Default, Debug)]
struct Instruction {
    nop: bool,
    addend: i64
}

impl Instruction {
    fn cycles(&self) -> u64 {
        if self.nop {
            1
        } else {
            2
        }
    }
}

impl fmt::Display for Instruction {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        if self.nop {
            write!(f, "noop")
        } else {
            write!(f, "addx {}", self.addend)
        }
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

    let mut instructions = Vec::<Instruction>::new();

    for line in reader {
        if let Ok(line) = line {
            match line.get(0..4).unwrap() {
                "noop" => instructions.push(Instruction { nop: true, addend: 0 }),
                "addx" => instructions.push(Instruction { nop: false, addend: line.get(5..).unwrap().parse::<i64>()? }),
                s => panic!("Unknown instruction: {}", s),
            }
        }
    }

    let measurements = vec![20, 60, 100, 140, 180, 220];

    let mut cycles: i64 = 0;
    let mut reg: i64 = 1;

    let mut total = 0;

    for instr in instructions {
        for i in 0..instr.cycles() {
            cycles += 1;

            if measurements.contains(&cycles) {
                total += cycles * reg;
                println!("{}: {}", cycles, cycles * reg);
            }

            if !instr.nop {
                match i {
                    0 => (),
                    1 => reg += instr.addend,
                    _ => panic!("Invalid i: {}", i)
                }
            }
        }
    }

    println!("total: {}", total);

    Ok(())
}
