import std.file;
import std.path;
import std.format;
import std.string;
import std.algorithm;
import server;
import client;
import commandsManager;

void Commands_Help(string[] args, Client client) {
	auto cmds = Server.Instance().cmds;

	if (args.length == 0) {
		foreach (key, value ; cmds.commands) {
			client.SendMessage(key ~ ", ");
		}
		client.SendMessage("\n");
	}
	else {
		if (!cmds.CommandExists(args[0])) {
			client.SendMessage(format("No such command: %s", args[0]));
			return;
		}

		foreach (line ; cmds.commands[args[0]].help) {
			client.SendMessage(line ~ "\n");
		}
	}
}

void Commands_Exit(string[] args, Client client) {
	Server.Instance().KickClient(client.username);
	throw new CommandQuitException();
}

void Commands_Messages(string[] args, Client client) {
	auto server = Server.Instance();

	foreach (ref message ; server.messages) {
		client.SendMessage(message ~ '\n');
	}
}

void Commands_Send(string[] args, Client client) {
	if (args.length == 0) {
		client.SendMessage("No message");
		return;
	}

	string message;

	foreach (ref arg ; args) {
		message ~= arg ~ " ";
	}
	message = strip(message);

	Server.Instance().SendGlobalMessage(client.username ~ ": " ~ message);
}

void Commands_Users(string[] args, Client client) {
	auto server = Server.Instance();

	foreach (ref c ; server.clients) {
		if (c.authenticated) {
			client.SendMessage(c.username ~ "\n");
		}
	}
}

void Commands_Uptime(string[] args, Client client) {
	auto server = Server.Instance();
	auto time   = server.uptime.peek.total!"seconds";

	client.SendMessage(
		format(
			"%d days, %d hours, %d minutes and %d seconds\n",
			time / 86400,
			time % 86400 / 3600,
			time % 86400 % 3600 / 60,
			time % 86400 % 3600 % 60
		)
	);
}

void Commands_Motd(string[] args, Client client) {
	client.SendMessage(readText(dirName(thisExePath()) ~ "/motd.txt"));
}

void Commands_Clear(string[] args, Client client) {
	client.SendMessage("\x1b[2J\x1b[H");
}
