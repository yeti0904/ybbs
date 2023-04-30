import std.stdio;
import core.thread;
import server;

void main() {
	auto server = Server.Instance();

	server.Init();

	while (server.running) {
		server.UpdateSockets();
		server.UpdateClients();

		Thread.sleep(dur!("msecs")(5));
	}
}
