use core::fmt;
use std::io::BufRead;
use std::string::ParseError;
use std::{env, io};
use std::fs::File;
use std::error::Error;
use std::str::FromStr;

#[derive(Clone, PartialEq, Eq)]
enum Input {
    Integer(u64),
    List(Vec<Input>)
}

#[derive(PartialEq, Eq)]
enum CompResult {
    Inconclusive,
    InOrder,
    NotInOrder
}

impl Input {
    fn consume(val: &str) -> (Self, usize) {
        match &val[0..1] {
            "[" => {
                // A possibly nested list
                let mut res = Vec::<Input>::new();

                let mut consumed = 1;

                loop {
                    match &val[consumed..consumed+1] {
                        "]" => break,
                        "," => consumed += 1,
                        _ => ()
                    }

                    let (parsed, consumed_partial) = Input::consume(&val[consumed..]);

                    res.push(parsed);

                    consumed += consumed_partial;
                }

                consumed += 1;
                
                (Input::List(res), consumed)
            },
            _ => {
                // An integer
                let mut consumed = 0;
                let mut res: u64  = 0;

                for ch in val.as_bytes() {
                    match ch {
                        b'0'..=b'9' => {
                            res = (res * 10) + u64::from(ch - b'0');
                            consumed += 1;
                        },
                        _ => break
                    }
                }

                (Input::Integer(res), consumed)
            }
        }
    }

    fn compare(&self, rhs: &Self) -> CompResult {
        if let (Input::List(l), Input::List(r)) = (self, rhs) {
            // Check every item
            for i in 0..usize::max(l.len(), r.len()) {
                if i >= l.len() && i < r.len() {
                    // Left ran out first
                    return CompResult::InOrder;
                } else if i < l.len() && i >= r.len() {
                    // Right ran out first
                    return CompResult::NotInOrder;
                }

                match l[i].compare(&r[i]) {
                    v @ CompResult::NotInOrder => return v,
                    v @ CompResult::InOrder => return v,
                    _ => ()
                }
            }

            return CompResult::Inconclusive;
        } else if let (Input::Integer(l), Input::Integer(r)) = (self, rhs) {
            if l == r {
                return CompResult::Inconclusive;
            } else if l < r {
                return CompResult::InOrder;
            } else {
                return CompResult::NotInOrder;
            }
        } else if let (Input::Integer(l), Input::List(_)) = (self, rhs) {
            return Input::List(vec![Input::Integer(*l)]).compare(rhs);
        } else if let (Input::List(_), Input::Integer(r)) = (self, rhs) {
            return self.compare(&Input::List(vec![Input::Integer(*r)]));
        }

        CompResult::Inconclusive

    }
}

impl FromStr for Input {
    type Err = ParseError;

    fn from_str(val: &str) -> Result<Self, Self::Err> {
        let (res, _) = Input::consume(val);

        Ok(res)
    }
}

impl fmt::Display for Input {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            Self::Integer(num) => write!(f, "{num}"),
            Self::List(subitems) => {
                write!(f, "[").expect("how1");

                for i in 0..subitems.len() {
                    write!(f, "{}", subitems[i]).expect("failed to write item somehow");

                    if i < (subitems.len() - 1) {
                        write!(f, ",").expect("how2");
                    }
                }

                write!(f, "]")
            }
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

    let mut operands = Vec::<Input>::new();

    let mut total = 0;
    let mut i = 0;
    for line in reader {
        if let Ok(line) = line {
            if !line.is_empty() {
                // Parse line
                operands.push(line.parse().unwrap());
            }

            if operands.len() == 2 {
                // println!("{}\n{}", operands[0], operands[1]);
                
                match operands[0].compare(&operands[1]) {
                    CompResult::InOrder => {
                        total += i + 1;

                        println!("{i} in order")
                    },
                    CompResult::NotInOrder => println!("{i} not in order"),
                    CompResult::Inconclusive => println!("{i} inconclusive")
                }
                
                i += 1;
                operands.clear();
            }
            
        }
    }

    println!("Total: {total}");

    Ok(())
}
