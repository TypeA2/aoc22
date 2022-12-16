use std::io::BufRead;
use std::{env, io};
use std::fs::File;
use std::error::Error;


fn main() -> Result<(), Box<dyn Error>> {
    let args: Vec<String> = env::args().collect();

    if args.len() != 2 {
        println!("No input file provided");
        std::process::exit(1);
    }

    let infile = File::open(&args[1])?;
    let reader = io::BufReader::new(infile).lines();

    for line in reader {
        if let Ok(line) = line {

        }
    }


    Ok(())
}
