use std::io::BufRead;
use std::ops::{Sub, Add, AddAssign};
use std::{env, io};
use std::fs::File;
use std::error::Error;
use std::string::ParseError;
use std::str::FromStr;
use std::fmt;

#[derive(Clone, Copy, PartialEq, Eq, Debug, Default)]
struct Point {
    x: i64,
    y: i64
}

impl Point {
    fn clamp(&self) -> Self {
        Point {
            x: i64::clamp(self.x, -1, 1),
            y: i64::clamp(self.y, -1, 1)
        }
    }
}

impl Sub<Point> for Point {
    type Output = Point;

    fn sub(self, rhs: Self) -> Self {
        Self {
            x: self.x - rhs.x,
            y: self.y - rhs.y
        }
    }
}

impl Add<Point> for Point {
    type Output = Point;

    fn add(self, rhs: Self) -> Self {
        Self {
            x: self.x + rhs.x,
            y: self.y + rhs.y
        }
    }
}

impl AddAssign for Point {
    fn add_assign(&mut self, other: Self) {
        *self = Self {
            x: self.x + other.x,
            y: self.y + other.y,
        }
    }
}

#[derive(Default, Debug, Clone)]
struct Path {
    path: Vec<Point>
}

impl Path {
    fn insert(&mut self, p: Point) {
        self.path.push(p)
    }

    fn points(&self) -> Vec<Point> {
        let mut res = Vec::<Point>::new();

        for p in &self.path {
            if res.is_empty() {
                res.push(*p);
            } else {
                // Make a line from the previous point
                let prev = *res.last().unwrap();
                let delta = (*p - prev).clamp();

                let mut cur = prev;
                while cur != *p {
                    cur += delta;

                    res.push(cur);
                }
            }
        }

        res
    }
}

impl FromStr for Point {
    type Err = ParseError;

    fn from_str(val: &str) -> Result<Self, Self::Err> {
        let coords: Vec<i64> = val.split(",").map(|s| s.parse().unwrap()).collect();

        if coords.len() != 2 {
            panic!("{} elements encoutnered", coords.len());
        }

        Ok(Point {
            x: coords[0],
            y: coords[1]
        })
    }
}

impl fmt::Display for Point {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "({}, {})", self.x, self.y)
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Cell {
    Air,
    Source,
    Sand,
    Rock
}

#[derive(Debug)]
struct Grid {
    left: i64,
    right: i64,
    height: i64,

    data: Vec<Vec<Cell>>
}

impl Grid {
    fn new(left: i64, right: i64, height: i64) -> Grid {
        let grid_data = vec![vec![Cell::Air; (right - left) as usize]; height as usize];

        let mut res = Grid {
            left,
            right,
            height,

            data: grid_data
        };

        res.set_at(500, 0, Cell::Source);

        res
    }

    #[allow(dead_code)]
    fn width(&self) -> i64 {
        self.right - self.left
    }

    #[allow(dead_code)]
    fn height(&self) -> i64 {
        self.height
    }

    fn get_at(&self, x: i64, y: i64) -> Cell {
        self.data[y as usize][(x - self.left) as usize]
    }

    fn set_at(&mut self, x: i64, y: i64, v: Cell) {
        self.data[y as usize][(x - self.left) as usize] = v
    }

    fn in_grid(&self, x: i64, y: i64) -> bool {
        (y < (self.data.len() as i64)) && ((x - self.left) < (self.data[y as usize].len() as i64))
    }

    // Return whether the unit came to rest
    fn drop(&mut self) -> bool {
        let mut sand = Point {
            x: 500,
            y: 0
        };

        loop {
            if !self.in_grid(sand.x, sand.y + 1) {
                return false;
            }

            match self.get_at(sand.x, sand.y + 1) {
                Cell::Air => sand.y += 1,
                Cell::Rock | Cell::Sand => {
                    // Try to move left, else try to move right 
                    let left = self.get_at(sand.x - 1, sand.y + 1);
                    if left != Cell::Air {
                        let right = self.get_at(sand.x + 1, sand.y + 1);
                        if right != Cell::Air {
                            self.set_at(sand.x, sand.y, Cell::Sand);
                            return true;
                        } else {
                            sand += Point { x: 1, y: 1 }
                        }
                    } else {
                        sand += Point { x: -1, y: 1 };
                    }
                },
                Cell::Source => panic!("how?")
            }
        }
    }
}

impl fmt::Display for Grid {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        writeln!(f, "left={}, right={}, height={}", self.left, self.right, self.height).expect("wtf");

        for y in 0..self.height {
            write!(f, "{: >3} ", y).expect("how");

            for x in self.left..self.right {
                write!(f, "{} ", match self.get_at(x, y) {
                    Cell::Air => '.',
                    Cell::Source => '+',
                    Cell::Sand => 'o',
                    Cell::Rock => '#'
                }).expect("tho");
            }

            writeln!(f, "").expect("fr");
        }
        Ok(())
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

    let mut paths = Vec::<Path>::new();

    let mut max_y = i64::MIN;
    let mut min_x = i64::MAX;
    let mut max_x = i64::MIN;
    for line in reader {
        if let Ok(line) = line {
            let mut path = Path::default();

            for p in line.split(" -> ") {
                let pt = p.parse::<Point>().unwrap();

                max_y = i64::max(max_y, pt.y);
                min_x = i64::min(min_x, pt.x);
                max_x = i64::max(max_x, pt.x);

                path.insert(pt);
            }

            paths.push(path);
        }
    }

    let mut grid = Grid::new(min_x - 1, max_x + 1, max_y + 1);

    for path in paths {
        for pt in path.points() {
            grid.set_at(pt.x, pt.y, Cell::Rock);
        }
    }

    let mut i = 0;
    loop {
        if !grid.drop() {
            break;
        }

        i += 1;
    }

    println!("{grid}\n{i}");

    Ok(())
}
