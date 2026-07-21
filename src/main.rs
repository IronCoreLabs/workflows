// This crate is a hello-world test fixture whose only purpose is to let
// `.github/workflows/rust-ci-test.yaml` exercise the reusable `rust-ci.yaml`
// workflow against this repo. It is not real software. The test below exists
// solely so the `cargo llvm-cov` coverage job reports non-zero line coverage
// instead of posting a confusing "0% coverage" check on every PR. There is
// nothing here worth investigating.

fn greeting() -> &'static str {
    "Hello, world!"
}

fn main() {
    println!("{}", greeting());
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn greeting_is_hello_world() {
        assert_eq!(greeting(), "Hello, world!");
    }
}
