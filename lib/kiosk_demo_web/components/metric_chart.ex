defmodule KioskDemoWeb.Components.MetricChart do
  @moduledoc """
  Canvas-based stacked-horizon chart driven entirely by `push_event/3`.

  The component itself renders only a `<canvas>` and a colocated JS hook.
  The metric data never touches the DOM; the parent LiveView calls
  `build_layers/1` and pushes the result with
  `push_event(socket, "chart:" <> id, %{layers: layers})`.

  ## Animation strategy

    * **Horizontal**: the whole chart scrolls smoothly to the left at
      `step/update_interval_ms` pixels per ms — exactly one "step"
      (`width / fixed_count`) per push interval. When a new push arrives
      the scroll offset resets to 0 and the data array shifts left,
      keeping the visible chart continuous (no horizontal hop).
    * **Vertical**: the rightmost point is animated. Each frame
      `animY += (pending - animY) * α`, rounded to 1 decimal so the math
      doesn't chase imperceptible fractions. The freshly-pushed value is
      *held* as `pending` and never quite reached; on the next push
      `animY` snaps to that previous `pending` (which slides into the
      fixed history one position left) and starts trending toward the
      new pending value.
    * Two off-canvas echo points (one on each side, copying the nearest
      visible value) keep the bezier curve continuous through the
      scrolling left/right edges.
  """

  use Phoenix.Component

  attr :id, :string, required: true
  attr :dark_color, :string, default: "transparent"
  attr :light_color, :string, default: "#f8fafc"
  attr :height, :integer, default: 120
  attr :update_interval_ms, :integer, default: 2000

  def line_chart(assigns) do
    ~H"""
    <div style="line-height: 0;">
      <canvas
        id={@id}
        phx-hook=".MetricCanvas"
        data-height={@height}
        data-bg-color={@dark_color}
        data-baseline-color={@light_color}
        data-update-interval-ms={@update_interval_ms}
        style={"display: block; width: 100%; height: #{@height}px; position: relative; top: 1px;"}
        aria-hidden="true"
      >
      </canvas>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".MetricCanvas">
        export default {
          mounted() {
            this.alpha = 0.06;        // fraction of remaining y-gap closed per frame
            this.snapEpsilon = 0.2;   // px below which we just snap and stop the y trend
            this.updateIntervalMs = parseFloat(this.el.dataset.updateIntervalMs) || 2000;
            this.lastPushTime = performance.now();
            this.layerState = null;
            this.setupCanvas();
            this.handleEvent("chart:" + this.el.id, payload => this.applyTarget(payload.layers));
            this._resizeObs = new ResizeObserver(() => {
              this.setupCanvas();
              if (this.layerState) {
                this.refreshGeometry();
                this.draw(this.currentProgress());
              }
            });
            this._resizeObs.observe(this.el);
          },
          destroyed() {
            if (this._raf) cancelAnimationFrame(this._raf);
            if (this._resizeObs) this._resizeObs.disconnect();
          },
          setupCanvas() {
            const h = parseInt(this.el.dataset.height);
            const w = Math.max(Math.round(this.el.clientWidth), 1);
            // Native DPR — no forced oversampling. The filled horizon shapes
            // don't visibly need the extra AA, and 2x bitmap on embedded
            // WebKit (software canvas2d) caps the framerate hard.
            const dpr = window.devicePixelRatio || 1;
            this.el.width = Math.round(w * dpr);
            this.el.height = Math.round(h * dpr);
            this.ctx = this.el.getContext("2d");
            this.ctx.scale(dpr, dpr);
            this.w = w;
            this.h = h;
          },
          currentProgress() {
            return Math.min((performance.now() - this.lastPushTime) / this.updateIntervalMs, 1);
          },
          applyTarget(layers) {
            this.lastPushTime = performance.now();
            if (!this.layerState) {
              this.layerState = layers.map(l => {
                const n = l.y.length;
                const last = n > 0 ? l.y[n - 1] : 0;
                const first = n > 0 ? l.y[0] : 0;
                return {
                  fill: l.fill,
                  // y-value at the just-off-canvas-left position. On the
                  // first push we have no earlier sample, so seed with the
                  // leftmost visible value (the bezier just extends flat).
                  echoLeft: first,
                  fixed: l.y.slice(0, Math.max(n - 1, 0)),
                  pending: last,
                  animY: last
                };
              });
            } else {
              layers.forEach((l, i) => {
                const state = this.layerState[i];
                if (!state) return;
                const n = l.y.length;
                state.fill = l.fill;
                // The sample that just slid off-canvas-left becomes the
                // new echo. This keeps the bezier control points entering
                // the leftmost visible point identical across the push, so
                // the visible curve doesn't twitch.
                state.echoLeft = state.fixed.length > 0
                  ? state.fixed[0]
                  : (n > 0 ? l.y[0] : state.echoLeft);
                state.fixed = l.y.slice(0, Math.max(n - 1, 0));
                // The trending point was approaching the previous pending but
                // by design never reached it; snap to it now so the shape
                // is continuous with the freshly-shifted-in history, then
                // start trending toward the newly-received value.
                state.animY = state.pending;
                state.pending = n > 0 ? l.y[n - 1] : state.pending;
              });
            }
            // Precompute the static portion of each layer's bezier path.
            // Only the rightmost 3 segments (those involving animY) need to
            // be recomputed per frame.
            this.refreshGeometry();
            this.startTicking();
          },
          refreshGeometry() {
            const w = this.w;
            for (const state of this.layerState) {
              const fixedLen = state.fixed.length;
              if (fixedLen === 0) {
                state.geom = null;
                continue;
              }
              const mainN = fixedLen + 1;
              const step = w / (mainN - 1);
              const renderedN = fixedLen + 3;

              // Untranslated x positions (xOffset applied via ctx.translate).
              const xs = new Array(renderedN);
              xs[0] = -step;
              for (let i = 0; i < fixedLen; i++) xs[i + 1] = i * step;
              xs[fixedLen + 1] = fixedLen * step;
              xs[fixedLen + 2] = (fixedLen + 1) * step;

              // Static y values: indices 0..fixedLen (echoLeft + fixed).
              const staticYs = new Array(fixedLen + 1);
              staticYs[0] = state.echoLeft;
              for (let i = 0; i < fixedLen; i++) staticYs[i + 1] = state.fixed[i];

              // Segments ending at indices 1..fixedLen-1 are fully static
              // (their y1, y2, p0, p3 are all in staticYs). The segment ending
              // at fixedLen has p3 = animY, so it's dynamic.
              const staticEnd = fixedLen - 1;
              const cps = new Array(staticEnd + 1);
              for (let i = 1; i <= staticEnd; i++) {
                const x1 = xs[i - 1], y1 = staticYs[i - 1];
                const x2 = xs[i], y2 = staticYs[i];
                const p0i = i - 2 < 0 ? 0 : i - 2;
                const p3i = i + 1;
                const p0x = xs[p0i], p0y = staticYs[p0i];
                const p3x = xs[p3i], p3y = staticYs[p3i];
                cps[i] = {
                  cp1x: x1 + (x2 - p0x) / 6,
                  cp1y: y1 + (y2 - p0y) / 6,
                  cp2x: x2 - (p3x - x1) / 6,
                  cp2y: y2 - (p3y - y1) / 6,
                  x2, y2
                };
              }

              state.geom = {
                xs, staticYs, cps, staticEnd, renderedN, step, fixedLen
              };
            }
          },
          startTicking() {
            if (this._raf) return;
            const tick = (now) => {
              const progress = Math.min((now - this.lastPushTime) / this.updateIntervalMs, 1);
              // Keep ticking while either the scroll progress hasn't reached 1
              // or any layer's y is still trending toward its pending value.
              let stillTicking = progress < 1;
              for (const state of this.layerState) {
                const delta = state.pending - state.animY;
                if (Math.abs(delta) < this.snapEpsilon) {
                  state.animY = state.pending;
                } else {
                  state.animY = Math.round((state.animY + delta * this.alpha) * 10) / 10;
                  stillTicking = true;
                }
              }
              this.draw(progress);
              if (stillTicking) {
                this._raf = requestAnimationFrame(tick);
              } else {
                this._raf = null;
              }
            };
            this._raf = requestAnimationFrame(tick);
          },
          draw(progress) {
            if (!this.layerState || !this.ctx) return;
            if (progress === undefined) progress = this.currentProgress();
            const ctx = this.ctx;
            const w = this.w;
            const h = this.h;

            const bg = this.el.dataset.bgColor;
            if (bg && bg !== "transparent") {
              ctx.fillStyle = bg;
              ctx.fillRect(0, 0, w, h);
            } else {
              ctx.clearRect(0, 0, w, h);
            }

            for (const state of this.layerState) {
              if (!state.geom) continue;
              const xOffset = -progress * state.geom.step;
              ctx.save();
              ctx.translate(xOffset, 0);
              this.drawLayer(state);
              ctx.restore();
            }

            const baseline = this.el.dataset.baselineColor;
            if (baseline) {
              ctx.fillStyle = baseline;
              ctx.fillRect(0, h - 1.5, w, 1.5);
            }
          },
          drawLayer(state) {
            const ctx = this.ctx;
            const h = this.h;
            const g = state.geom;
            const xs = g.xs;
            const staticYs = g.staticYs;
            const cps = g.cps;
            const staticEnd = g.staticEnd;
            const renderedN = g.renderedN;
            const fixedLen = g.fixedLen;
            const animY = state.animY;

            ctx.fillStyle = state.fill;
            ctx.beginPath();
            ctx.moveTo(xs[0], staticYs[0]);

            // Static segments — bezier control points cached at push time.
            for (let i = 1; i <= staticEnd; i++) {
              const cp = cps[i];
              ctx.bezierCurveTo(cp.cp1x, cp.cp1y, cp.cp2x, cp.cp2y, cp.x2, cp.y2);
            }

            // Dynamic segments — recomputed per frame because animY changes.
            // Three segments end at fixedLen, fixedLen+1, fixedLen+2.
            // Segment ending at fixedLen: y1=staticYs[fixedLen-1], y2=staticYs[fixedLen], p3.y=animY.
            if (fixedLen >= 1) {
              const x1 = xs[fixedLen - 1];
              const y1 = staticYs[fixedLen - 1];
              const x2 = xs[fixedLen];
              const y2 = staticYs[fixedLen];
              const p0i = fixedLen - 2 < 0 ? 0 : fixedLen - 2;
              const p0x = xs[p0i], p0y = staticYs[p0i];
              const p3x = xs[fixedLen + 1], p3y = animY;
              ctx.bezierCurveTo(
                x1 + (x2 - p0x) / 6, y1 + (y2 - p0y) / 6,
                x2 - (p3x - x1) / 6, y2 - (p3y - y1) / 6,
                x2, y2
              );
            }
            // Segment ending at fixedLen+1: y1=staticYs[fixedLen], y2=animY, p3.y=animY.
            {
              const x1 = xs[fixedLen], y1 = staticYs[fixedLen];
              const x2 = xs[fixedLen + 1], y2 = animY;
              const p0x = xs[fixedLen - 1 < 0 ? 0 : fixedLen - 1];
              const p0y = staticYs[fixedLen - 1 < 0 ? 0 : fixedLen - 1];
              const p3x = xs[fixedLen + 2], p3y = animY;
              ctx.bezierCurveTo(
                x1 + (x2 - p0x) / 6, y1 + (y2 - p0y) / 6,
                x2 - (p3x - x1) / 6, y2 - (p3y - y1) / 6,
                x2, y2
              );
            }
            // Segment ending at fixedLen+2: y1=animY, y2=animY, p3 clamped to itself.
            {
              const x1 = xs[fixedLen + 1], y1 = animY;
              const x2 = xs[fixedLen + 2], y2 = animY;
              const p0x = xs[fixedLen], p0y = staticYs[fixedLen];
              const p3x = xs[fixedLen + 2], p3y = animY;
              ctx.bezierCurveTo(
                x1 + (x2 - p0x) / 6, y1 + (y2 - p0y) / 6,
                x2 - (p3x - x1) / 6, y2 - (p3y - y1) / 6,
                x2, y2
              );
            }

            ctx.lineTo(xs[renderedN - 1], h);
            ctx.lineTo(xs[0], h);
            ctx.closePath();
            ctx.fill();
          }
        }
      </script>
    </div>
    """
  end

  @doc """
  Build the push_event payload (a list of `%{fill, y}` layer maps) from
  a chart spec.

  The spec keys mirror what the chart visually wants:

    * `:series` — primary metric series (list of `%{value: v}` maps)
    * `:overlays` — list of overlay specs:
      `%{series: [...], fill: "#...", height_scale: 1.5, min: nil, max: nil}`
    * `:height` — **must** match the `:height` attr on the chart component;
      y-coords are pre-normalised against it
    * `:light_color` — fill colour for the primary series
    * `:min`, `:max`, `:height_scale` — primary bounds (defaults: nil, nil, 1.0)

  Push with `push_event(socket, "chart:" <> id, %{layers: build_layers(spec)})`.
  """
  def build_layers(spec) do
    h = spec[:height] || 120

    primary_opts = %{
      height: h,
      min: spec[:min],
      max: spec[:max],
      height_scale: spec[:height_scale]
    }

    overlay_layers =
      Enum.map(spec[:overlays] || [], fn ov ->
        build_layer(
          ov[:series] || [],
          %{
            height: h,
            min: ov[:min],
            max: ov[:max],
            height_scale: ov[:height_scale]
          },
          ov[:fill] || "#1f2937"
        )
      end)

    primary_layer =
      build_layer(spec[:series] || [], primary_opts, spec[:light_color] || "#f8fafc")

    overlay_layers ++ [primary_layer]
  end

  defp build_layer([], _opts, fill), do: %{fill: fill, y: []}

  defp build_layer(series, opts, fill) do
    h = opts[:height] || 120
    values = Enum.map(series, & &1.value)
    {min_v, max_v} = bounds(values, opts[:min], opts[:max])
    span = max(max_v - min_v, 1.0e-6)
    scale = opts[:height_scale] || 1.0
    effective_h = h * scale
    top_margin = 2.0

    ys =
      Enum.map(values, fn v ->
        y_raw = h - (v - min_v) / span * effective_h
        Float.round(clamp(y_raw, top_margin, h * 1.0), 1)
      end)

    %{fill: fill, y: ys}
  end

  defp bounds(values, min_override, max_override) do
    {min_v, max_v} = Enum.min_max(values)
    min_v = if is_number(min_override), do: min_override, else: floor_to_step(min_v)
    max_v = if is_number(max_override), do: max_override, else: ceil_to_step(max_v)
    max_v = if max_v <= min_v, do: min_v + 1.0, else: max_v
    {min_v * 1.0, max_v * 1.0}
  end

  defp floor_to_step(v), do: Float.floor(v * 1.0)
  defp ceil_to_step(v), do: Float.ceil(v * 1.0)

  defp clamp(v, lo, _hi) when v < lo, do: lo
  defp clamp(v, _lo, hi) when v > hi, do: hi
  defp clamp(v, _lo, _hi), do: v
end
