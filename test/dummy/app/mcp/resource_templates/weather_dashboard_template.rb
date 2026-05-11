# frozen_string_literal: true

class WeatherDashboardTemplate < ApplicationMCPResTemplate
  description "Interactive weather dashboard UI for the weather tool"
  uri_template "ui://weather/dashboard"
  mime_type ActionMCP::MIME_TYPE_APP_HTML

  HTML = <<~HTML
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <title>Weather</title>
      <style>
        :root { color-scheme: light dark; font-family: system-ui, sans-serif; }
        body { margin: 0; padding: 1.25rem; }
        .card { max-width: 28rem; padding: 1rem 1.25rem; border-radius: 0.75rem;
                background: color-mix(in srgb, currentColor 6%, transparent); }
        h1 { margin: 0 0 0.5rem; font-size: 1.25rem; }
        .temp { font-size: 3rem; font-weight: 600; line-height: 1; }
        .row { display: flex; gap: 1rem; margin-top: 0.75rem; font-size: 0.9rem;
               opacity: 0.8; }
        .icon { font-size: 2.5rem; }
      </style>
    </head>
    <body>
      <div class="card" role="region" aria-label="Weather summary">
        <h1 id="loc">Weather</h1>
        <div class="icon" aria-hidden="true">&#x2600;</div>
        <div class="temp"><span id="temp">--</span>&deg;</div>
        <div class="row">
          <div>Humidity <span id="hum">--</span>%</div>
          <div>Wind <span id="wind">--</span> km/h</div>
        </div>
      </div>
      <script>
        (function () {
          function set(id, v) { var el = document.getElementById(id); if (el) el.textContent = v; }
          window.addEventListener("message", function (event) {
            var data = event.data && event.data.result;
            if (!data || !data.current) return;
            if (data.metadata && data.metadata.location_found) set("loc", data.metadata.location_found);
            set("temp", Math.round(data.current.temperature));
            set("hum", data.current.humidity);
            set("wind", data.current.wind_speed);
          });
        }());
      </script>
    </body>
    </html>
  HTML

  # Per ext-apps apps.mdx, csp/permissions/prefersBorder live on the resource
  # content (`resources/read`), not on the listing entry. The class-level
  # `meta` macro emits to the listing only, so we set these via the Resource
  # constructor instead.
  def resolve
    ActionMCP::Content::Resource.new(
      self.class.uri_template,
      ActionMCP::MIME_TYPE_APP_HTML,
      text: HTML,
      meta: {
        ui: {
          csp: { connectDomains: %w[api.openweathermap.org] },
          prefersBorder: true
        }
      }
    )
  end
end
