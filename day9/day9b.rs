use std::io::BufRead;
use std::{env, io};
use std::fs::File;
use std::error::Error;
use std::collections::HashSet;
use std::ops::{self, Deref};
use std::fmt;
use std::hash::Hash;

#[derive(Copy, Clone, PartialEq, Eq, Hash, Default, Debug)]
struct Point {
    x: i64,
    y: i64,
}

impl Point {
    fn adjacent(&self, other: &Self) -> bool {
        ((self.x == other.x + 1) || (self.x == other.x) || (self.x == other.x - 1))
            && ((self.y == other.y + 1) || (self.y == other.y) || (self.y == other.y - 1))
    }

    fn extended_close_gap(&self, other: Self) -> Option<Self> {
        /* Check of `other` is in one of the positions marked with x and move to adjacent
         * zxxxz
         * x,.,x
         * x.o.x
         * x,.,x
         * zxxxz
         */

        let left_options = vec![
            *self + Point { x: -2, y:  1 },
            *self + Point { x: -2, y:  0 },
            *self + Point { x: -2, y: -1 }
        ];

        if left_options.contains(&other) {
            return Some(Point {
                x: self.x - 1,
                y: self.y
            })
        }

        if other == (*self + Point { x: -2, y: -2 }) {
            return Some(Point {
                x: self.x - 1,
                y: self.y - 1
            })
        }

        let up_options = vec![
            *self + Point { x: -1, y:  2 },
            *self + Point { x:  0, y:  2 },
            *self + Point { x:  1, y:  2 }
        ];

        if up_options.contains(&other) {
            return Some(Point {
                x: self.x,
                y: self.y + 1
            })
        }

        if other == (*self + Point { x: -2, y: 2 }) {
            return Some(Point {
                x: self.x - 1,
                y: self.y + 1
            })
        }

        let right_options = vec![
            *self + Point { x:  2, y:  1 },
            *self + Point { x:  2, y:  0 },
            *self + Point { x:  2, y: -1 }
        ];

        if right_options.contains(&other) {
            return Some(Point {
                x: self.x + 1,
                y: self.y
            })
        }

        if other == (*self + Point { x: 2, y: 2 }) {
            return Some(Point {
                x: self.x + 1,
                y: self.y + 1
            })
        }

        let down_options = vec![
            *self + Point { x: -1, y: -2 },
            *self + Point { x:  0, y: -2 },
            *self + Point { x:  1, y: -2 }
        ];

        if down_options.contains(&other) {
            return Some(Point {
                x: self.x,
                y: self.y - 1
            })
        }

        if other == (*self + Point { x: 2, y: -2 }) {
            return Some(Point {
                x: self.x + 1,
                y: self.y - 1
            })
        }

        println!("Invalid extended close gap: {} -> {}", *self, other);
        None
    }
    
}

impl ops::Add<Point> for Point {
    type Output = Point;

    fn add(self, rhs: Self) -> Self {
        Self {
            x: self.x + rhs.x,
            y: self.y + rhs.y,
        }
    }
}

impl ops::AddAssign for Point {
    fn add_assign(&mut self, other: Self) {
        *self = Self {
            x: self.x + other.x,
            y: self.y + other.y,
        }
    }
}

impl fmt::Display for Point {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "({}, {})", self.x, self.y)
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

    //let mut head = Point::default();
    let mut rope = vec![Point::default(); 10];

    let mut visited = HashSet::<Point>::new();

    visited.insert(Point { x: 0, y: 0 });
    
    'readloop: for line in reader {
        if let Ok(line) = line {
            let count = line.get(2..).unwrap().parse::<i64>()?;
            let addend = match line.as_bytes()[0] as char {
                'U' => Point { x:  0, y:  1 },
                'R' => Point { x:  1, y:  0 },
                'D' => Point { x:  0, y: -1 },
                'L' => Point { x: -1, y:  0 },
                c => panic!("Invalid character {}", c),
            };

            for _ in 0..count {
                // Move head first
                rope[0] += addend;

                let mut parent = rope[0];

                for p in &mut rope[1..] {
                    if !p.adjacent(&parent) {
                        let new = parent.extended_close_gap(*p);

                        match new {
                            Some(x) => *p = x,
                            None => break 'readloop
                        };

                        parent = *p;
                    } else {
                        break;
                    }
                }

                visited.insert(*rope.last().unwrap());
            }
        }
    }

    let mut min = Point::default();
    let mut max = Point::default();
    for p in &rope {
        if p.x > max.x {
            max.x = p.x;
        }

        max.x = i64::max(p.x, max.x);
        max.y = i64::max(p.y, max.y);

        min.x = i64::min(p.x, min.x);
        min.y = i64::min(p.y, min.y);
    }

    for p in visited.iter() {
        max.x = i64::max(p.x, max.x);
        max.y = i64::max(p.y, max.y);

        min.x = i64::min(p.x, min.x);
        min.y = i64::min(p.y, min.y);
    }

    //let width = max.x - min.x + 3;
   // let height = max.y - min.y + 3;

    min += Point { x: -1, y: -1 };
    max += Point { x: 2, y: 2 };

    //println!("{} {}", width, height);

    for y in (min.y..max.y).rev()  {
        print!("{: >3} | ", y);
        for x in min.x..max.x {
            let cur = Point { x, y };
            if rope.contains(&cur) {
                if *rope.first().unwrap() == cur {
                    print!("H ");
                } else if *rope.last().unwrap() == cur {
                    print!("T ");
                } else {
                    print!("x ");
                }
            } else if x == 0 && y == 0 {
                print!("s ");
            } else if visited.contains(&cur) {
                print!("# ");
            } else {
                print!(". ");
            }
        }

        print!("\n");
    }

    print!("     ");

    for _ in min.x..max.x {
        print!("--");
    }

    print!("\n     ");

    for i in min.x..max.x {
        print!("{} ", i);
    }

    print!("\n");

    println!("{}", visited.len());

    Ok(())
}
