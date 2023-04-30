import std.algorithm;
import data;
import client;

struct Command {
	void function(string[], Client) func;
	string[]                        help;
	UserRank                        minRank;
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

	void AddCommand(
		string name, void function(string[], Client) func, UserRank minRank,
		string[] help
	) {
		commands[name] = Command(func, help, minRank);
	}

	void Run(string[] args, Client client) {
		commands[args[0]].func(args.remove(0), client);
	}

	bool CommandExists(string name) {
		return (name in commands) !is null;
	}
}
