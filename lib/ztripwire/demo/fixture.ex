defmodule Ztripwire.Demo.Fixture do
  alias Ztripwire.Accounts.Character
  alias Ztripwire.Demo.State
  alias Ztripwire.Mapping.{Comment, MapConnection, MapSystem, Signature}
  alias Ztripwire.Mapping.Map, as: ChainMap
  alias Ztripwire.Masks.Mask
  alias Ztripwire.Settings.UserSettings

  @systems [
    %{
      solar_system_id: 31_000_001,
      name: "J150321",
      alias: "Home",
      sys_class: "C2",
      favorite: true,
      x: 120.0,
      y: 120.0
    },
    %{solar_system_id: 31_000_002, name: "J150322", sys_class: "C3", x: 360.0, y: 260.0},
    %{solar_system_id: 31_000_003, name: "J150323", sys_class: "C5", x: 600.0, y: 140.0},
    %{
      solar_system_id: 31_000_004,
      name: "J150324",
      sys_class: "C4",
      x: 780.0,
      y: 330.0,
      effect: "Magnetar",
      statics: ["C247", "H900"]
    },
    %{solar_system_id: 31_000_005, name: "J150325", sys_class: "C6", x: 480.0, y: 470.0},
    %{solar_system_id: 31_000_006, name: "J150326", sys_class: "C1", x: 880.0, y: 200.0},
    %{solar_system_id: 30_000_142, name: "Jita", security: 0.9, x: 880.0, y: 380.0},
    %{solar_system_id: 30_000_201, name: "Tama", security: 0.2, x: 700.0, y: 540.0},
    %{solar_system_id: 30_000_301, name: "1DQ1-A", security: -1.0, x: 450.0, y: 560.0},
    %{
      solar_system_id: 31_000_010,
      name: "Raravoss",
      alias: "Pochven",
      sys_class: "Trig",
      x: 200.0,
      y: 540.0
    },
    %{solar_system_id: 31_000_011, name: "J150327", sys_class: "C4", x: 240.0, y: 300.0},
    %{solar_system_id: 31_000_012, name: "J150328", sys_class: "C2", x: 120.0, y: 460.0},
    %{solar_system_id: 30_000_216, name: "Dodixie", security: 0.9, x: 240.0, y: 620.0},
    %{solar_system_id: 31_000_013, name: "J150329", sys_class: "C5", x: 300.0, y: 30.0},
    %{solar_system_id: 31_000_014, name: "J150330", sys_class: "C2", x: 500.0, y: 20.0},
    %{solar_system_id: 30_002_187, name: "Amarr", security: 1.0, x: 700.0, y: 40.0},
    %{solar_system_id: 31_000_015, name: "J150331", sys_class: "C5", x: 980.0, y: 480.0},
    %{
      solar_system_id: 31_000_016,
      name: "J150332",
      sys_class: "C4",
      effect: "Red Giant",
      x: 620.0,
      y: 660.0
    },
    %{solar_system_id: 31_000_017, name: "J150333", sys_class: "C4", x: 60.0, y: 620.0},
    %{solar_system_id: 31_000_018, name: "J150334", sys_class: "C1", x: 620.0, y: 300.0},
    %{solar_system_id: 30_002_537, name: "Rens", security: 0.9, x: 460.0, y: 120.0},
    %{solar_system_id: 31_000_019, name: "J150335", sys_class: "C6", x: 830.0, y: 90.0},
    %{solar_system_id: 31_000_020, name: "J150336", sys_class: "C5", x: 950.0, y: 280.0},
    %{solar_system_id: 31_000_021, name: "J150337", sys_class: "C3", x: 780.0, y: 420.0},
    %{solar_system_id: 31_000_022, name: "J150338", sys_class: "C4", x: 1_020.0, y: 200.0},
    %{unknown: true, solar_system_id: 0, name: "unknown", x: 780.0, y: 540.0},
    %{unknown: true, solar_system_id: 0, name: "unknown", x: 1_120.0, y: 340.0}
  ]

  @links [
    {0, 1, "O477", "stable", "stable"},
    {1, 2, "N770", "destab", "stable"},
    {2, 3, "E175", "stable", "critical"},
    {2, 4, "V753", "critical", "stable"},
    {4, 5, "Q317", "stable", "stable"},
    {5, 6, "N110", "stable", "stable"},
    {3, 7, "N290", "stable", "stable"},
    {3, 8, "K329", "stable", "stable"},
    {4, 9, "F216", "stable", "stable"},
    {0, 10, "Y683", "stable", "stable"},
    {10, 11, "N766", "stable", "stable"},
    {11, 12, "B274", "stable", "stable"},
    {0, 13, "N062", "stable", "stable"},
    {13, 14, "D364", "stable", "stable"},
    {14, 15, "B274", "stable", "stable"},
    {6, 16, "M555", "stable", "stable"},
    {8, 17, "O128", "destab", "stable"},
    {9, 18, "R081", "stable", "stable"},
    {2, 19, "Y790", "stable", "stable"},
    {15, 20, "A641", "stable", "stable"},
    {15, 21, "B041", "stable", "stable"},
    {3, 22, "H900", "stable", "stable"},
    {19, 23, "K162", "stable", "stable"},
    {21, 24, "K162", "stable", "stable"},
    {23, 25, "N062", "stable", "stable"},
    {24, 26, "B274", "stable", "stable"},
    {4, 15, "B520", "stable", "stable"}
  ]

  @signatures %{
    0 => [
      %{
        sig_id: "ABC-123",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (O477)"
      },
      %{
        sig_id: "ABC-124",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (Y683)"
      },
      %{
        sig_id: "ABC-125",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (N062)"
      },
      %{
        sig_id: "DEF-456",
        kind: "signature",
        site_type: "combat",
        type_name: "Serpentis Frigate Den"
      },
      %{sig_id: "GHI-789", kind: "signature", site_type: "data", type_name: "Ruined Data Site"}
    ],
    1 => [
      %{
        sig_id: "JKL-012",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (O477)"
      },
      %{
        sig_id: "BCD-124",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (N770)"
      },
      %{sig_id: "MNO-345", kind: "signature", site_type: "relic", type_name: "Ruined Relic Site"},
      %{sig_id: "PQR-678", kind: "anomaly", site_type: "combat", type_name: "Forsaken Hub"}
    ],
    2 => [
      %{
        sig_id: "STU-902",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (N770)"
      },
      %{
        sig_id: "VWX-234",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (E175)"
      },
      %{
        sig_id: "TUV-681",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (V753)"
      },
      %{
        sig_id: "TUV-682",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (Y790)"
      },
      %{
        sig_id: "STU-901",
        kind: "signature",
        site_type: "gas",
        type_name: "Sizeable Perimeter Withdrawal"
      },
      %{
        sig_id: "YZA-567",
        kind: "signature",
        site_type: "ore",
        type_name: "Rarified Core Deposit"
      }
    ],
    3 => [
      %{
        sig_id: "EFG-123",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (E175)"
      },
      %{
        sig_id: "FGH-892",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (N290)"
      },
      %{
        sig_id: "FGH-893",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (K329)"
      },
      %{
        sig_id: "FGH-894",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (H900)"
      },
      %{sig_id: "BCD-890", kind: "anomaly", site_type: "combat", type_name: "Sanctum"}
    ],
    4 => [
      %{
        sig_id: "HIJ-457",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (V753)"
      },
      %{
        sig_id: "HIJ-458",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (Q317)"
      },
      %{
        sig_id: "IJK-124",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (F216)"
      },
      %{
        sig_id: "LPQ-701",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (B520)"
      },
      %{sig_id: "HIJ-456", kind: "signature", site_type: "data", type_name: "Central Data Site"},
      %{
        sig_id: "KLM-789",
        kind: "signature",
        site_type: "combat",
        type_name: "Blood Raider Naval Shipyard"
      }
    ],
    5 => [
      %{
        sig_id: "NOP-012",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (Q317)"
      },
      %{
        sig_id: "IJK-125",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (N110)"
      },
      %{sig_id: "QRS-345", kind: "signature", site_type: "relic", type_name: "Ruined Relic Site"}
    ],
    6 => [
      %{
        sig_id: "KLM-791",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (N110)"
      },
      %{
        sig_id: "TUV-679",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (M555)"
      },
      %{sig_id: "TUV-678", kind: "anomaly", site_type: "combat", type_name: "Forsaken Hub"},
      %{sig_id: "WXY-901", kind: "signature", site_type: "data", type_name: "Central Data Site"},
      %{sig_id: "AAA-111", kind: "signature", site_type: "unknown"},
      %{sig_id: "BBB-222", kind: "signature", site_type: "unknown"}
    ],
    7 => [
      %{
        sig_id: "ZAB-235",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (N290)"
      },
      %{
        sig_id: "ZAB-234",
        kind: "signature",
        site_type: "combat",
        type_name: "Serpentis Rally Point"
      },
      %{
        sig_id: "CDE-567",
        kind: "signature",
        site_type: "gas",
        type_name: "Vast Frontier Reservoir"
      },
      %{sig_id: "CCC-333", kind: "signature", site_type: "unknown"}
    ],
    8 => [
      %{
        sig_id: "IJK-123",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (K329)"
      },
      %{
        sig_id: "FGH-891",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (O128)"
      },
      %{sig_id: "FGH-890", kind: "anomaly", site_type: "combat", type_name: "Sanctum"}
    ],
    9 => [
      %{
        sig_id: "LMN-456",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (F216)"
      },
      %{
        sig_id: "LMN-458",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (R081)"
      }
    ],
    10 => [
      %{
        sig_id: "OPQ-789",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (Y683)"
      },
      %{
        sig_id: "OPQ-790",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (N766)"
      },
      %{sig_id: "RST-012", kind: "signature", site_type: "combat", type_name: "Guristas Hub"}
    ],
    11 => [
      %{
        sig_id: "UVW-345",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (N766)"
      },
      %{
        sig_id: "UVW-347",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (B274)"
      }
    ],
    12 => [
      %{
        sig_id: "XYZ-679",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (B274)"
      },
      %{sig_id: "XYZ-678", kind: "anomaly", site_type: "combat", type_name: "Forsaken Hub"}
    ],
    13 => [
      %{
        sig_id: "KLM-790",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (N062)"
      },
      %{
        sig_id: "KLM-792",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (D364)"
      }
    ],
    14 => [
      %{
        sig_id: "NOP-013",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (D364)"
      },
      %{
        sig_id: "NOP-014",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (B274)"
      }
    ],
    15 => [
      %{
        sig_id: "QRS-346",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (B274)"
      },
      %{
        sig_id: "QRS-347",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (A641)"
      },
      %{
        sig_id: "RST-015",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (B041)"
      },
      %{
        sig_id: "LPQ-702",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (B520)"
      }
    ],
    16 => [
      %{
        sig_id: "RST-013",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (M555)"
      }
    ],
    17 => [
      %{
        sig_id: "TUV-680",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (O128)"
      }
    ],
    18 => [
      %{
        sig_id: "UVW-346",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (R081)"
      }
    ],
    19 => [
      %{
        sig_id: "VWX-235",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (Y790)"
      }
    ],
    20 => [
      %{
        sig_id: "WXY-902",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (A641)"
      }
    ],
    21 => [
      %{
        sig_id: "XYZ-680",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (B041)"
      }
    ],
    22 => [
      %{
        sig_id: "YZA-568",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (H900)"
      }
    ],
    23 => [
      %{
        sig_id: "KLM-793",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (K162)"
      },
      %{
        sig_id: "KLM-795",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (N062)"
      }
    ],
    24 => [
      %{
        sig_id: "KLM-794",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (K162)"
      },
      %{
        sig_id: "KLM-796",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (B274)"
      }
    ]
  }

  @paste Enum.join(
           [
             "TUV-679\tCosmic Signature\tUnstable Wormhole (M555)\t100.00%\t1.21 AU",
             "KLM-791\tCosmic Signature\tUnstable Wormhole (N110)\t100.00%\t0.42 AU",
             "TUV-678\tCosmic Anomaly\tForsaken Hub\t100.00%\t1.05 AU",
             "WXY-901\tCosmic Signature\tCentral Data Site\t87.50%\t2.40 AU",
             "AAA-111\tCosmic Signature\t100.00%\t3.10 AU",
             "QWE-111\tCosmic Signature\t12.50%\t4.20 AU",
             "RTY-222"
           ],
           "\n"
         )

  def paste, do: @paste

  def build do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    character = %Character{
      id: 1,
      eve_id: Ztripwire.Demo.character_eve_id(),
      name: Ztripwire.Demo.character_name(),
      is_admin: true,
      ship_on_chain: true,
      character_on_chain: true,
      automapper: true,
      refresh_token: nil,
      last_login_at: now,
      inserted_at: now,
      updated_at: now
    }

    mask = %Mask{
      id: 2,
      name: "Demo Mask",
      kind: "demo",
      owner_character_id: character.id,
      inserted_at: now,
      updated_at: now
    }

    map = %ChainMap{
      id: 3,
      name: "Demo",
      mask_id: mask.id,
      home_solar_system_id: 31_000_001,
      home_name: "J150321",
      inserted_at: now,
      updated_at: now
    }

    state = %State{
      character: character,
      mask: mask,
      maps: [map],
      members: %{mask.id => [character]},
      settings: %UserSettings{},
      layouts: [],
      next_id: 10
    }

    {systems, state} = build_systems(state, map, now)
    {connections, state} = build_connections(state, map, systems, now)
    {signatures, state} = build_signatures(state, systems, character, now)
    {comments, state} = build_comments(state, systems, mask, character, now)

    positions =
      Map.new(systems, fn system ->
        {{map.id, system.id}, %{x: system.x, y: system.y}}
      end)

    %{
      state
      | systems: systems,
        connections: connections,
        signatures: signatures,
        comments: comments,
        positions: positions
    }
  end

  defp build_systems(state, map, now) do
    Enum.map_reduce(@systems, state, fn attrs, state ->
      {id, state} = State.take_id(state)

      system = %MapSystem{
        id: id,
        mask_id: map.mask_id,
        solar_system_id: attrs[:solar_system_id],
        name: attrs[:name],
        alias: attrs[:alias],
        security: attrs[:security],
        sys_class: attrs[:sys_class],
        effect: attrs[:effect],
        statics: attrs[:statics] || [],
        favorite: attrs[:favorite] || false,
        unknown: attrs[:unknown] || false,
        x: attrs[:x] || 0.0,
        y: attrs[:y] || 0.0,
        inserted_at: now,
        updated_at: now
      }

      {system, state}
    end)
  end

  defp build_connections(state, map, systems, now) do
    Enum.map_reduce(@links, state, fn {from_idx, to_idx, hole_type, mass, time}, state ->
      {id, state} = State.take_id(state)
      from = Enum.at(systems, from_idx)
      to = Enum.at(systems, to_idx)

      connection = %MapConnection{
        id: id,
        mask_id: map.mask_id,
        from_system_id: from.id,
        to_system_id: to.id,
        from_system: from,
        to_system: to,
        hole_type: hole_type,
        mass_status: mass,
        time_status: time,
        inserted_at: now,
        updated_at: now
      }

      {connection, state}
    end)
  end

  defp build_signatures(state, systems, character, now) do
    systems
    |> Enum.with_index()
    |> Enum.flat_map_reduce(state, fn {system, idx}, state ->
      @signatures
      |> Elixir.Map.get(idx, [])
      |> Enum.map_reduce(state, fn attrs, state ->
        {id, state} = State.take_id(state)
        life = attrs[:life_length] || 259_200
        inserted = DateTime.add(now, -idx * 37 - 5, :minute)

        signature = %Signature{
          id: id,
          map_system_id: system.id,
          sig_id: attrs.sig_id,
          kind: attrs[:kind] || "signature",
          type_name: attrs[:type_name],
          type_id: attrs[:type_id],
          site_type: attrs[:site_type] || "unknown",
          bookmark: attrs[:bookmark],
          life_length: life,
          expires_at: DateTime.add(now, life, :second),
          created_by_id: character.id,
          updated_by_id: character.id,
          created_by: character,
          updated_by: character,
          inserted_at: inserted,
          updated_at: inserted
        }

        {signature, state}
      end)
    end)
  end

  defp build_comments(state, systems, mask, character, now) do
    jita = Enum.find(systems, &(&1.name == "Jita")) || List.first(systems)

    bodies = Ztripwire.Mapping.welcome_notes() ++ [@paste]

    Enum.map_reduce(bodies, state, fn body, state ->
      {id, state} = State.take_id(state)

      comment = %Comment{
        id: id,
        map_system_id: jita.id,
        character_id: character.id,
        character: character,
        mask_id: mask.id,
        mask: mask,
        body: body,
        inserted_at: now,
        updated_at: now
      }

      {comment, state}
    end)
  end
end
