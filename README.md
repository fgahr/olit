# olit -- A simpler tilo
Working on `tilo` I saw that much of the complexity in that project was due to
a couple of fundamental design decisions, namely the client-server operation
and the sqlite backend (with alternative backends possible).

While I in no way regret those decisions, in part because the curiosity and
ambition that led to them was one of the main motivations for the project as a
whole, they add very little benefit in normal operation. In fact, as of
writing `olit`, that benefit may be nonexistent.

So I decided to attempt writing an alternative version with no server and
using a plaintext database. This version would then be feasible to write in
`Bash`, making use of only a few common Unix utilities. While I have no intention
to port all functionality from `tilo`, especially when it comes to more complex
querying, it does feature a reasonable subset, weighing in at less than
250 lines of code. New query options can be added with relative ease, so long
as only one task and one duration is requested at a time.

Listeners are supported as follows: A listener process has to create a named
pipe (FIFO) named `~/.config/olit/listeners/$PID`, (where `$PID` is the listener's
process ID), and read from it. Upon task changes (start/stop/abort) a short
message will be written to these pipes. Sample output is available by using
the `listen` command. Pipes whose process dies will be cleaned up but this is
not super reliable.

# Installation
Running `make` will symlink the `main.sh` file to `~/bin/olit`. Please make
sure the directory exists and is included in your `$PATH`. Feel free to do
anything else with it and rename it as you please.

# Purpose
This project is meant as a cautionary tale regarding complexity cost incurred
by seemingly harmless design decisions. And to make the point that Unix, with
all of its utilities, is awesome.

Would it be easier to write this program in Python? Absolutely. Would it be
clearer and more concise? Maybe. Would I have had as much fun writing it? No.

By the way, `tilo` said it took me about 4 hours to write this, a good part
of which was spent consulting the `info` manual for `Bash`. Also, since the
work was split between computers and I haven't implemented remote servers yet,
I couldn't track it exactly.

# Usage
This section is relegated to the lower parts of this README, partly because
I don't expect anyone to use it. Usage is very similar to `tilo`, output
is slightly different. Some commands only make sense for client-server
interaction and are therefore omitted.

For any further details, read the source code. I did my best to make it
clear and understandable.
