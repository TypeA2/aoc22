use std::io::BufRead;
use std::mem::swap;
use std::{env, io};
use std::fs::File;
use std::error::Error;

#[derive(Default, Debug)]
enum Rhs {
    #[default]
    Old,
    Num(i64)
}

#[derive(Default, Debug)]
enum Operation {
    #[default]
    None,
    Add(Rhs),
    Mul(Rhs)
}

#[derive(Default, Debug)]
struct Monkey {
    items: Vec<i64>,
    op: Operation,

    divisible_by: i64,
    target_true: usize,
    target_false: usize,

    items_inspected: usize
}

struct Move {
    target: usize,
    value: i64
}

fn main() -> Result<(), Box<dyn Error>> {
    let args: Vec<String> = env::args().collect();

    if args.len() != 2 {
        println!("No input file provided");
        std::process::exit(1);
    }

    let infile = File::open(&args[1])?;
    let reader = io::BufReader::new(infile).lines();

    let mut monkeys = Vec::<Monkey>::new();

    for line in reader {
        if let Ok(line) = line {
            if line.len() == 0 {
                continue;
            }

            match line.get(0..6).unwrap() {
                "Monkey" => monkeys.push(Monkey::default()),
                "  Star" =>  {
                    let items = line.get(18..).unwrap();

                    let cur = monkeys.last_mut().unwrap();

                    for item in items.split(", ") {
                        cur.items.push(item.parse::<i64>().unwrap());
                    }
                },
                "  Oper" => { 
                    let cond = line.get(23..).unwrap();

                    let cur = monkeys.last_mut().unwrap();

                    cur.op = match cond {
                        "* old" => Operation::Mul(Rhs::Old),
                        "+ old" => Operation::Add(Rhs::Old),
                        &_ => {
                            let rhs = Rhs::Num(cond.get(2..).unwrap().parse::<i64>().unwrap());

                            match cond.get(0..1).unwrap() {
                                "+" => Operation::Add(rhs),
                                "*" => Operation::Mul(rhs),
                                &_ => panic!("Invalid line: {}", line)
                            }
                        }
                    }
                },
                "  Test" => {
                    let num = line.get(21..).unwrap().parse::<i64>().unwrap();

                    let cur = monkeys.last_mut().unwrap();

                    cur.divisible_by = num;
                },
                "    If" => {
                    let cur = monkeys.last_mut().unwrap();

                    match line.get(7..8).unwrap() {
                        "t" => cur.target_true = line.get(29..).unwrap().parse::<usize>().unwrap(),
                        "f" => cur.target_false = line.get(30..).unwrap().parse::<usize>().unwrap(),
                        &_ => panic!("What: {}", line)
                    }
                }
                _ => panic!("Invalid line: {} ({})", line, line.len())
            }
        }
    }

    for _ in 0..20 {
        for i in 0..monkeys.len() {
            let mut moves = Vec::<Move>::new();

            {
                let m = &mut monkeys[i];
                for item in &m.items {
                    let new_item = match m.op {
                        Operation::Add(Rhs::Old) => item + item,
                        Operation::Add(Rhs::Num(num)) => item + num,
                        Operation::Mul(Rhs::Old) => item * item,
                        Operation::Mul(Rhs::Num(num)) => item * num,
                        _ => panic!("you done fucked up")
                    } / 3;

                    moves.push(Move {
                        target: match new_item % m.divisible_by {
                            0 => m.target_true,
                            _ => m.target_false
                        },
                        value:  new_item
                    });

                    m.items_inspected += 1;
                }

                m.items.clear();
            }

            for Move { target, value } in moves {
                monkeys[target].items.push(value);
            }
        }        
    }

    let mut max0 = 0;
    let mut max1 = 0;

    for m in monkeys {
        max1 = usize::max(max1, m.items_inspected);

        if max1 > max0 {
            swap(&mut max0, &mut max1);
        }
    }

    println!("{} * {} = {}", max0, max1, max0 * max1);

    Ok(())
}
