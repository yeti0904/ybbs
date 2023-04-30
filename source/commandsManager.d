import std.algorithm;
import data;
import client;

struct Command {
	void function(string[], Client) func;
	string[]                        help;
}

class CommandQuitException : Exception {
	this(string msg = "", string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line);
	}
}

class CommandManager {
	Command[string] commands;

	this() {}
	~this() {}

	void AddCommand(string name, void function(string[], Client) func, string[] help) {
		commands[name] = Command(func, help);
	}

	void Run(string[] args, Client client) {
		commands[args[0]].func(args.remove(0), client);
	}

	bool CommandExists(string name) {
		return (name in commands) !is null;
	}
}
