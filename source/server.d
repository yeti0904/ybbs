import std.file;
import std.path;
import std.json;
import std.ascii;
import std.stdio;
import std.string;
import std.socket;
import std.algorithm;
import std.datetime.stopwatch;
import data;
import client;
import commands;
import commandsManager;

struct ServerConfig {
	string ip;
	ushort port;
}

class Server {
	bool           running;
	ServerConfig   config;
	Socket         socket;
	SocketSet      serverSet;
	SocketSet      clientSet;
	Client[]       clients;
	CommandManager cmds;
	string[]       messages;
	DataManager    data;
	StopWatch      uptime;

	this() {
		JSONValue configFile;
	
		string configPath = dirName(thisExePath()) ~ "/config.json";
		if (exists(configPath)) {
			configFile = readText(configPath).parseJSON();
		}
		else {
			configFile = parseJSON("{}");

			configFile["ip"]   = "0.0.0.0";
			configFile["port"] = 25565;

			std.file.write(configPath, configFile.toPrettyString());
		}

		config.ip   = configFile["ip"].str;
		config.port = cast(ushort) configFile["port"].integer;
	
		uptime = StopWatch(AutoStart.no);
	
		running = true;

		serverSet = new SocketSet();
		clientSet = new SocketSet();

		data = new DataManager();

		cmds = new CommandManager();
		cmds.AddCommand("help", &Commands_Help, UserRank.Guest, [
			"help {command}",
			"if command is given, show how to use the command",
			"if not, show a list of commands"
		]);
		cmds.AddCommand("exit", &Commands_Exit, UserRank.Guest, [
			"exit",
			"closes your session"
		]);
		cmds.AddCommand("messages", &Commands_Messages, UserRank.Guest, [
			"messages",
			"gives you the last 20 messages"
		]);
		cmds.AddCommand("send", &Commands_Send, UserRank.Guest, [
			"send [message]",
			"sends a message with your username to global chat"
		]);
		cmds.AddCommand("users", &Commands_Users, UserRank.Guest, [
			"users",
			"gives you a list of online users"
		]);
		cmds.AddCommand("uptime", &Commands_Uptime, UserRank.Guest, [
			"uptime",
			"shows server uptime"
		]);
		cmds.AddCommand("motd", &Commands_Motd, UserRank.Guest, [
			"motd",
			"shows server motd"
		]);
		cmds.AddCommand("clear", &Commands_Clear, UserRank.Guest, [
			"clear",
			"clears the screen"
		]);
		cmds.AddCommand("ban", &Commands_Ban, UserRank.Moderator, [
			"ban",
			"bans an IP"
		]);
		cmds.AddCommand("watch", &Commands_Watch, UserRank.Moderator, [
			"watch",
			"watches a username, so it gets IP banned if it ever connects"
		]);
		cmds.AddCommand("setrank", &Commands_SetRank, UserRank.Operator, [
			"setrank [name] [rank]",
			"sets name's rank to rank"
		]);
	}

	~this() {
		if (socket) {
			socket.close();
		}
	}

	static Server Instance() {
		static Server instance;

		if (!instance) {
			instance = new Server();
		}

		return instance;
	}

	void Init() {
		socket          = new Socket(AddressFamily.INET, SocketType.STREAM);
		socket.blocking = false; // single-threaded server
		socket.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);

		version (Posix) {
			socket.setOption(
				SocketOptionLevel.SOCKET, cast(SocketOption) SO_REUSEPORT, 1
			);
		}

		socket.bind(new InternetAddress(config.ip, config.port));
		socket.listen(10);

		uptime.start();

		writefln("Listening at %s:%d", config.ip, config.port);
	}

	void UpdateSockets() {
		serverSet.reset();
		clientSet.reset();

		serverSet.add(socket);
		if (clients) {
			foreach (ref client ; clients) {
				clientSet.add(client.socket);
			}
		}

		bool   success = true;
		Socket newClientSocket;

		try {
			newClientSocket = socket.accept();
		}
		catch (Throwable) {
			success = false;
		}

		if (success) {
			newClientSocket.blocking = false;

			Client newClient = new Client();
			newClient.socket = newClientSocket;

			if (data.banList.canFind(newClientSocket.remoteAddress.toAddrString())) {
				newClient.SendMessage("You are banned from this BBS\n");
				newClient.socket.close();
				goto loop;
			}

			clients ~= newClient;
			clientSet.add(newClientSocket);

			writefln("%s connected", newClientSocket.remoteAddress.toAddrString());

			newClient.SendMessage(
				readText(dirName(thisExePath()) ~ "/motd.txt") ~
				"\nUsername: "
			);
		}

		loop:

		foreach (ref client ; clients) {
			if (!clientSet.isSet(client.socket)) {
				continue;
			}

			ubyte[] incoming = new ubyte[1024];

			long received = client.socket.receive(incoming);

			if ((received == 0) || (received == Socket.ERROR)) {
				continue;
			}

			incoming = incoming[0 .. received];
			//client.inBuffer ~= incoming;

			foreach (ref b ; incoming) {
				if ((b >= 240) && (b < 32)) {
					continue;
				}

				client.inBuffer ~= b;
			}
		}
	}

	void UpdateClients() {
		foreach (i, ref client ; clients) {
			if (client.inBuffer.length == 0) {
				continue;
			}
/*
			client.socket.send(cast(void[]) [client.inBuffer[0]]);
			client.inBuffer = client.inBuffer.remove(0);
*/
			if (client.inBuffer[$ - 1] == 10) {
				if (!client.HandleInput()) {
					client.socket.close();
					clients = clients.remove(i);
					return;
				}
				client.inBuffer = [];
			}
		}
	}

	void KickClient(string name) {
		foreach (i, ref client ; clients) {
			if (client.authenticated && (client.username == name)) {
				writefln("Kicked %s", name);
				client.socket.close();
				clients = clients.remove(i);
				return;
			}
		}
		writefln("Failed to kick %s", name);
	}

	void KickIP(string ip) {
		foreach (i, ref client ; clients) {
			if (client.socket.remoteAddress.toAddrString() == ip) {
				client.socket.close();
				clients = clients.remove(i);
			}
		}
	}

	void SendGlobalMessage(string message) {
		messages ~= message;
		if (messages.length > 20) {
			messages = messages.remove(0);
		}
	}

	bool UserOnline(string name) {
		foreach (ref client ; clients) {
			if (client.username == name) {
				return true;
			}
		}
		
		return false;
	}

	bool IPOnline(string ip) {
		foreach (ref client ; clients) {
			if (client.socket.remoteAddress.toAddrString() == ip) {
				return true;
			}
		}

		return false;
	}

	Client GetClient(string name) {
		foreach (ref client ; clients) {
			if (client.username == name) {
				return client;
			}
		}

		assert(0);
	}
}
