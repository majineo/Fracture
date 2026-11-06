--!strict
-- Signal minimal pour la communication entre modules (à la place de _G ou de BindableEvents).
-- Studio : ReplicatedStorage > Shared > Util > Signal
--
-- Exemple :
--   local Loaded = Signal.new()
--   local conn = Loaded:Connect(function(player, data) ... end)
--   Loaded:Fire(player, data)
--   conn:Disconnect()
--
-- Chaque écouteur est exécuté dans son propre thread (task.spawn) : une erreur dans un
-- écouteur n'empêche pas les autres de s'exécuter.

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
}

local Signal = {}

function Signal.new<T...>(): Signal<T...>
	local listeners: { { handler: (T...) -> (), connection: Connection } } = {}

	local signal = {}

	function signal.Connect(_self: Signal<T...>, handler: (T...) -> ()): Connection
		local connection = { Connected = true } :: any
		function connection.Disconnect(conn: Connection)
			if not conn.Connected then
				return
			end
			conn.Connected = false
			for index, entry in listeners do
				if entry.connection == conn then
					table.remove(listeners, index)
					break
				end
			end
		end
		table.insert(listeners, { handler = handler, connection = connection })
		return connection
	end

	function signal.Fire(_self: Signal<T...>, ...: T...)
		-- Copie : un écouteur peut se déconnecter pendant le Fire.
		local snapshot = table.clone(listeners)
		for _, entry in snapshot do
			if entry.connection.Connected then
				task.spawn(entry.handler, ...)
			end
		end
	end

	function signal.DisconnectAll(_self: Signal<T...>)
		for _, entry in listeners do
			entry.connection.Connected = false
		end
		table.clear(listeners)
	end

	return (signal :: any) :: Signal<T...>
end

return table.freeze(Signal)
