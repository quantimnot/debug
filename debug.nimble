version       = "0.1.0"
author        = "quantimnot"
description   = "debug utilities"
license       = "MIT"
installExt    = @["nim"]
srcDir        = "."
bin         = @["nimgdb", "nimlldb"]

requires "nimpy"
requires "cligen"
