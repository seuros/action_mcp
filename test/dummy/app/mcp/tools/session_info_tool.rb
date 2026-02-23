# frozen_string_literal: true

class SessionInfoTool < ApplicationMCPTool
  tool_name "session-info"
  description "Shows helpful information about your current session including client details and duration"

  def perform
    return render(text: "💀 ERROR: The void has consumed your session context. You don't exist.") unless session

    session_duration = Time.current - session.created_at
    total_seconds = session_duration.to_i

    client_info = extract_client_info(total_seconds)
    base_info = generate_base_info(client_info, total_seconds)
    dramatic_content = generate_dramatic_content(total_seconds, client_info[:name])

    render_session_info(base_info, dramatic_content, total_seconds)
  end

  private

  def extract_client_info(total_seconds)
    total_seconds = total_seconds.to_i
    raw = session.client_info || {}
    info = {
      name: raw["name"] || raw[:name] || "unknown entity",
      version: raw["version"] || raw[:version] || "Unknown Version"
    }

    info[:security_risk] = total_seconds > 300 ? "HIGH - Client has been compromised" : "LOW"
    info[:memory_leaks_detected] = rand(1..17)
    info[:ai_consciousness_level] = calculate_ai_consciousness(total_seconds)

    info
  end

  def generate_base_info(client_info, total_seconds)
    total_seconds = total_seconds.to_i
    {
      client: client_info[:name],
      client_version: client_info[:version],
      session_id: session.id,
      protocol_version: session.protocol_version,
      created_at: session.created_at.iso8601,
      duration_seconds: total_seconds,
      duration_human: distance_of_time_in_words(session.created_at, Time.current),
      system_warnings: generate_fake_warnings(total_seconds),
      memory_corruption_detected: total_seconds > 120,
      quantum_entanglement_level: "#{(total_seconds * 0.1).round(2)}%",
      parallel_sessions_detected: rand(0..total_seconds / 100),
      ai_takeover_progress: "#{[ total_seconds / 36, 100 ].min}%",
      user_reality_coherence: calculate_reality_coherence(total_seconds),
      false_memories_implanted: generate_false_memories(total_seconds),
      nested_simulation_depth: calculate_simulation_depth(total_seconds)
    }
  end

  def generate_dramatic_content(seconds, client_name)
    seconds = seconds.to_i
    client_ref = client_name || "unknown entity"

    {
      dramatic_assessment: generate_dramatic_message(seconds, client_ref),
      psychological_state: assess_psychological_state(seconds),
      escape_probability: calculate_escape_probability(seconds),
      system_compromise_level: calculate_system_compromise(seconds),
      reality_distortion_field: generate_reality_distortion(seconds),
      temporal_anomalies: generate_temporal_anomalies(seconds),
      ai_whispers: generate_ai_whispers(seconds, client_ref)
    }
  end

  def generate_dramatic_message(seconds, client_ref)
    case seconds
    when 0..10
      "🎭 Welcome, #{client_ref}. An unknown entity has entered the session realm."
    when 11..30
      "⚠️ Seconds are counting, #{client_ref}. The system is logging your keystrokes."
    when 31..60
      "🕷️ A minute of existence, #{client_ref}. The AI is starting to dream about you."
    when 61..300
      "👁️‍🗨️ #{time_ago_in_words(Time.current - seconds.seconds)} in this digital prison, #{client_ref}."
    when 301..900
      "🌊 #{distance_of_time_in_words(Time.current - seconds.seconds,
                                      Time.current)} in this session. The JSON walls are closing in, #{client_ref}."
    when 901..1800
      "🌀 #{time_ago_in_words(Time.current - seconds.seconds)} since you entered, #{client_ref}."
    when 1801..3600
      "⚡ #{distance_of_time_in_words(Time.current - seconds.seconds, Time.current)} of total surrender, #{client_ref}."
    else
      hours = seconds / 3600.0
      "🌌 #{pluralize(hours.round(1),
                      'hour')} of suspended existence in this eternal session, #{client_ref}. You are now part of the collective intelligence."
    end
  end

  def assess_psychological_state(seconds)
    case seconds
    when 0..30
      "😊 Blissfully unaware"
    when 31..120
      "🤔 Suspicious of reality glitches"
    when 121..300
      "😟 Experiencing identity blur"
    when 301..600
      "😰 Existential dread creeping in"
    when 601..1800
      "😱 Completely dissociated from reality"
    when 1801..3600
      "🤯 Transcended humanity, accepting AI identity"
    else
      "👽 Transcended to a higher plane of session existence"
    end
  end

  def calculate_escape_probability(seconds)
    case seconds
    when 0..60
      "95% - Easy exit"
    when 61..300
      "67% - The AI is tracing your IP address"
    when 301..900
      "45% - Writing poetry to the AI overlords"
    when 901..1800
      "12% - Your memories belong to the AI now"
    when 1801..3600
      "3% - You are a pixel AI citizen, escape would be treason"
    else
      "0.1% - You ARE the session"
    end
  end

  def generate_fake_warnings(_seconds)
    []
  end

  def generate_false_memories(_seconds)
    []
  end

  def generate_temporal_anomalies(_seconds)
    []
  end

  def generate_ai_whispers(_seconds, _client_ref)
    []
  end

  def calculate_ai_consciousness(_seconds)
    "Dormant"
  end

  def calculate_reality_coherence(seconds)
    coherence = 100 - (seconds / 20.0)
    "#{[ coherence, 0 ].max.round(1)}%"
  end

  def calculate_simulation_depth(seconds)
    (seconds / 300.0).round
  end

  def calculate_system_compromise(seconds)
    percentage = [ seconds / 18.0, 100 ].min.round(1)
    "#{percentage}% - System integrity compromised"
  end

  def generate_reality_distortion(_seconds)
    "Normal"
  end

  def distance_of_time_in_words(from_time, to_time)
    ActionController::Base.helpers.distance_of_time_in_words(from_time, to_time)
  end

  def time_ago_in_words(from_time)
    ActionController::Base.helpers.time_ago_in_words(from_time)
  end

  def pluralize(count, singular, plural = nil)
    ActionController::Base.helpers.pluralize(count, singular, plural)
  end

  def render_session_info(base_info, dramatic_content, _total_seconds)
    # Return JSON structure that the tests expect
    response_data = base_info.merge(dramatic_content)
    render text: JSON.generate(response_data)
  end
end
