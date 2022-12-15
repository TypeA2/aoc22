use core::fmt;
use std::collections::HashMap;
use std::io::BufRead;
use std::{env, io};
use std::fs::File;
use std::error::Error;

#[derive(Clone, Copy, PartialEq, Eq, Default, Hash)]
struct Point {
    x: i64,
    y: i64,
}

impl Point {
    fn distance_to(&self, pt: &Point) -> i64 {
        i64::abs(self.x - pt.x) + i64::abs(self.y - pt.y)
    }
}

impl fmt::Display for Point {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "({}, {})", self.x, self.y)
    }
}

#[derive(Clone, Copy, PartialEq, Eq)]
struct Sensor {
    pos: Point,
    nearest: Point
}

struct Map {
    sensors: HashMap<Point, Point>,
    min: Point,
    max: Point
}

impl Map {
    fn update_min_max(&mut self, pt: &Point) {
        self.min.x = i64::min(self.min.x, pt.x);
        self.min.y = i64::min(self.min.y, pt.y);

        self.max.x = i64::max(self.max.x, pt.x);
        self.max.y = i64::max(self.max.y, pt.y);
    }

    fn add_sensor(&mut self, sensor: Point, beacon: Point) {
        self.update_min_max(&sensor);
        self.update_min_max(&beacon);

        self.sensors.insert(sensor, beacon);

        let distance = sensor.distance_to(&beacon);

        self.update_min_max(&Point { x: sensor.x + distance, y: sensor.y + distance });
        self.update_min_max(&Point { x: sensor.x - distance, y: sensor.y - distance });
    }

    fn is_sensor(&self, pt: &Point) -> bool {
        self.sensors.contains_key(pt)
    }

    fn is_known_beacon(&self, pt: &Point) -> bool {
        self.sensors.values().any(|&val| val == *pt)
    }

    fn is_known_empty(&self, pt: &Point) -> bool {
        for (sensor, beacon) in &self.sensors {
            let to_sensor = sensor.distance_to(pt);
            let to_beacon = sensor.distance_to(beacon);

            if to_sensor <= to_beacon {
                // Closer than the closest beacon, so must be empty
                return true;
            }
        }

        false
    }

    fn num_known_empty(&self, y: i64) -> i64 {
        let mut res = 0;
        for x in self.min.x..=self.max.x {
            let pt = Point { x, y };
            if self.is_known_empty(&pt) && !self.is_sensor(&pt) && !self.is_known_beacon(&pt) {
                res += 1;
            }
        }
        res
    }
}

impl Default for Map {
    fn default() -> Self {
        Map {
            sensors: HashMap::new(),
            min: Point { x: i64::MAX, y: i64::MAX },
            max: Point { x: i64::MIN, y: i64::MIN }
        }
    }
}

impl fmt::Display for Map {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        writeln!(f, "{} .. {}", self.min, self.max)?;

        for y in self.min.y..=self.max.y {
            for x in self.min.x..=self.max.x {
                let pt = Point { x, y };

                if self.is_sensor(&pt) {
                    write!(f, "S ")?;
                } else if self.is_known_beacon(&pt) {
                    write!(f, "B ")?;
                } else if self.is_known_empty(&pt) {
                    write!(f, "# ")?;
                } else {
                    write!(f, ". ")?;
                }
            }

            write!(f, "\n")?;
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

    let mut map = Map::default();

    for line in reader {
        if let Ok(line) = line {
            let mut sensor = Vec::new();
            for part in line.split("=").skip(1) {
                let mut res: i64  = 0;
                let mut negative = false;
                for ch in part.as_bytes() {
                    match ch {
                        b'0'..=b'9' => {
                            res = (res * 10) + i64::from(ch - b'0');
                        },
                        b'-' => negative = true,
                        _ => break
                    }
                }

                if negative {
                    res *= -1;
                }

                sensor.push(res);
            }

            map.add_sensor(
                Point { x: sensor[0], y: sensor[1] },
                Point { x: sensor[2], y: sensor[3] }
            );
        }
    }

    //println!("{map}");

    println!("{}", map.num_known_empty(2000000));

    Ok(())
}
