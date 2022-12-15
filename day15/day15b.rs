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

    #[allow(dead_code)]
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

    fn find_beaon(&self, min: Point, max: Point) -> Option<Point> {
        let mut edges = Vec::<Point>::new();

        for (sensor, beacon) in &self.sensors {
            let distance = 1 + sensor.distance_to(beacon);

            let mut vertical = 0;
            let start = i64::clamp(sensor.x - distance, min.x, max.x);
            let end = i64::clamp(sensor.x + distance, min.x, max.x);

            for x in start..=end {
                let top = Point {
                    x,
                    y: sensor.y + vertical
                };
                //print!("{top} ");
                if top.y >= min.y && top.y <= max.y && !self.is_known_empty(&top) {
                    edges.push(top);
                }

                let bot = Point {
                    x,
                    y: sensor.y + vertical
                };
                //println!("{bot}");

                if bot.y >= min.y && bot.y <= max.y && !self.is_known_empty(&bot) {
                    edges.push(bot);
                }

                vertical += if x >= sensor.x { -1 } else { 1 };
            }
            
        }

        let mut unique_edges = HashMap::<Point, i64>::new();

        println!("{}", edges.len());

        for pt in edges {
            unique_edges.entry(pt).and_modify(|e| { *e += 1 }).or_insert(0);
        }

        match unique_edges.keys().count() {
            0 => None,
            1 => Some(**unique_edges.keys().collect::<Vec<&Point>>().first().unwrap()),
            2.. => panic!("Multiple options"),
            _ => panic!("impossible lol")
        }
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

    let beacon = map.find_beaon(Point { x: 0, y: 0 }, Point { x: 4000000, y: 4000000 });
    //let beacon = map.find_beaon(Point { x: 0, y: 0 }, Point { x: 20, y: 20 });

    if beacon.is_some() {
        let pt = beacon.unwrap();
        println!("{} -> {}", pt, (pt.x * 4000000) + pt.y);
    } else {
        println!("No beacon found");
    }
    

    Ok(())
}
