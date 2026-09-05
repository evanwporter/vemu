local lint = require("lint")

lint.linters.verilator.args = {
	"--sv",
	"-Wall",
	"-Wno-fatal",
	"--bbox-sys",
	"--bbox-unsup",
	"--lint-only",
	"-f",
	"build/cores/slang.f",
}
