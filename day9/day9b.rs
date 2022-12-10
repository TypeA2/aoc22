use std::io::BufRead;
use std::{env, io};
use std::fs::File;
use std::error::Error;
use std::collections::HashSet;
use std::ops;
use std::fmt;
use std::hash::Hash;

#[derive(Copy, Clone, PartialEq, Eq, Hash, Default, Debug)]
struct Point {
    x: i64,
    y: i64,
}

impl Point {
    fn adjacent(&self, other: Self) -> bool {
        ((self.x == other.x + 1) || (self.x == other.x) || (self.x == other.x - 1))
            && ((self.y == other.y + 1) || (self.y == other.y) || (self.y == other.y - 1))
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
    let mut rope = [Point::default(); 10];

    let mut visited = HashSet::<Point>::new();

    visited.insert(Point { x: 0, y: 0 });
    
    for line in reader {
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
                let mut next_old = rope[0];
                // Move head first
                rope[0] += addend;

                let mut next = rope[0];

                for i in 1..rope.len() {
                    // If this element is no longer adjacent to the next element
                    if !next.adjacent(rope[i]) {
                        println!("true");
                        let tmp_old = rope[i];

                        // Move this element to the previous position of the next element
                        rope[i].x = next_old.x;
                        rope[i].y = next_old.y;

                        next_old = tmp_old;
                        next = rope[i];

                        visited.insert(*rope.last().unwrap());
                    } else {
                        // Subsequent elements can't have moved
                        break;
                    }
                }
            }
        }
    }

    for point in &visited {
        println!("{}", point)
    }

    println!("{}", visited.len());

    Ok(())
}
