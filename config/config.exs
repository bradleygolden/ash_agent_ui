import Config

config :ash_agent_ui,
  generators: [timestamp_type: :utc_datetime]

config :phoenix, :json_library, Jason
