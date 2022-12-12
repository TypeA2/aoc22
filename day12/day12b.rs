use core::fmt;
use std::io::BufRead;
use std::ops::{Add, Sub};
use std::time::Instant;
use std::{env, io};
use std::fs::File;
use std::error::Error;
use std::collections::{HashSet, HashMap, VecDeque};

#[derive(Debug, Default, PartialEq, Eq, Hash, Clone, Copy)]
struct Point {
    x: i64,
    y: i64
}

impl Point {
    fn max() -> Self {
        Point {
            x: i64::MAX,
            y: i64::MAX,
        }
    }

    fn get_from<T: Copy>(&self, src: &Vec<Vec<T>>) -> T {
        src[self.y as usize][self.x as usize]
    }
}

impl Add for Point {
    type Output = Self;

    fn add(self, other: Self) -> Self {
        Self {
            x: self.x + other.x,
            y: self.y + other.y,
        }
    }
}

impl Sub for Point {
    type Output = Self;

    fn sub(self, other: Self) -> Self {
        Self {
            x: self.x - other.x,
            y: self.y - other.y,
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

    let mut heightmap = Vec::<Vec<u8>>::new();

    let mut end = Point::default();

    let mut dist_orig = HashMap::<Point, usize>::new();
    let mut q_orig = HashSet::<Point>::new();

    let mut starts = Vec::<Point>::new();

    let mut y = 0;
    for line in reader {
        if let Ok(line) = line {
            let mut x = 0;

            heightmap.push(Vec::<u8>::new());

            let cur = heightmap.last_mut().unwrap();

            for c in line.bytes() {
                let v =  Point { x, y };

                q_orig.insert(v);
                dist_orig.insert(v, usize::MAX);

                cur.push(match c {
                    b'S' => {
                        starts.push(v);

                        0
                    },
                    b'E' => {
                        end = v;

                        25
                    },
                    ch => {
                        if ch == b'a' {
                            starts.push(v);
                        }

                        ch - b'a'
                    }
                });

                x += 1;
            }
        }

        y += 1;
    }

    let mut shortest = usize::MAX;
    'outer: for start in starts {
        let begin = Instant::now();

        let mut dist = dist_orig.clone();
        let mut prev = HashMap::<Point, Point>::new();
        let mut q = q_orig.clone();

        dist.insert(start, 0);
        // Dijkstra
        while !q.is_empty() {
            let mut u = Point::max();

            let mut current_min  = usize::MAX;
            for p in &q {
                let d = dist[&p];

                if d < current_min {
                    u = *p;
                    current_min = d;
                }
            }

            if u == Point::max() {
                //dbg!(start);
                //dbg!(q);
                //dbg!(dist);
                //dbg!(u);
                //panic!("invalid state");
                continue 'outer;
            } else if u == end {
                break;
            }

            q.remove(&u);


            let neighbors = [
                // Up, right, down, left
                u + Point { x: 0, y: 1 },
                u + Point { x: 1, y: 0 },
                u - Point { x: 0, y: 1 },
                u - Point { x: 1, y: 0 },
            ];

            for v in neighbors {
                if q.contains(&v) {
                    let mut alt = dist[&u];

                    let u_height = u.get_from(&heightmap);
                    let v_height = v.get_from(&heightmap);

                    // New one may be at most 1 higher. 2 or more higher should never be taken
                    if alt == usize::MAX || v_height > (u_height + 1) {
                        // usize::MAX < x will always be false
                        continue;
                    } else {
                        alt += 1;
                    }

                    if alt < dist[&v] {
                        dist.insert(v, alt);
                        prev.insert(v, u);
                    }

                }
            }
        }

        // Reconstruct path
        let mut path = VecDeque::<Point>::new();
        let mut u = end;
        if !prev.contains_key(&u) {
            dbg!(prev);
            panic!("path not found");
        }

        while prev.contains_key(&u) {
            path.push_front(u);

            u = prev[&u];
        }

        /*
        for p in &path {
            print!("{} ->", p);
        }*/

        let duration = begin.elapsed();

        println!("({:?}) from {} is {} long", duration, path.front().unwrap(), path.len());

        shortest = usize::min(shortest, path.len());
    }

    println!("shortest path is {}", shortest);

    /*
    for y in 0..heightmap.len() {
        for x in 0..heightmap[y].len() {
            let cur = Point { x: x as i64, y: y as i64 };

            if cur == start {
                print!("  S");
            } else if cur == end {
                print!("  E");
            } else {
                print!(" {: >2}", cur.get_from(&heightmap));
            }
        }
        println!();
    }*/

    Ok(())
}
