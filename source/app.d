import std.stdio;
import core.thread;
import server;

void main() {
	auto  server = Server.Instance();
	ulong ticks;

	server.Init();

	while (server.running) {
		server.UpdateSockets();
		server.UpdateClients();

		if (ticks % 12000 == 0) {
			server.CheckClients();
		}

		++ ticks;
		Thread.sleep(dur!("msecs")(5));
	}
}
