defmodule ExcessibilityStorybook.Inspector do
  @moduledoc """
  An example story that inspects any component story's variations:

    * **Sounds like**: roughly what a screen reader announces, element by element.
    * **Focus order**: tab stops numbered on the component, with problems listed.
    * **Stress**: the variation at 320px, with 200% text, with WCAG text spacing,
      through color-vision filters and blur, with clipping and sideways scroll reported.

      defmodule Storybook.Accessibility.Inspector do
        use PhoenixStorybook.Story, :example
        use ExcessibilityStorybook.Inspector, backend: MyAppWeb.Storybook
      end

  Pass `storybook_path:` if the storybook isn't mounted at `/storybook`. Needs the
  `XsbFrame` hook from `priv/static/excessibility_storybook.js` registered in the
  storybook's JS. "Sounds like" is computed from the DOM with
  dom-accessibility-api; it approximates a screen reader, it isn't one.
  """

  use Phoenix.Component

  defmacro __using__(opts) do
    quote do
      @xsb_opts unquote(opts)

      @impl true
      def mount(params, session, socket),
        do: ExcessibilityStorybook.Inspector.mount(params, session, socket, @xsb_opts)

      @impl true
      def handle_event(event, params, socket),
        do: ExcessibilityStorybook.Inspector.handle_event(event, params, socket)

      @impl true
      def render(assigns), do: ExcessibilityStorybook.Inspector.render(assigns)
    end
  end

  @views [sounds: "Sounds like", focus: "Focus order", stress: "Stress"]

  @stress [
    %{id: "plain", label: "As designed", width: nil, filter: nil},
    %{id: "reflow", label: "320px wide (reflow)", width: 320, filter: nil},
    %{id: "text-200", label: "Text at 200%", width: nil, filter: nil},
    %{id: "text-spacing", label: "WCAG text spacing", width: nil, filter: nil},
    %{
      id: "protanopia",
      label: "Protanopia (no red cones)",
      width: nil,
      filter: "url(#xsb-protanopia)"
    },
    %{
      id: "deuteranopia",
      label: "Deuteranopia (no green cones)",
      width: nil,
      filter: "url(#xsb-deuteranopia)"
    },
    %{
      id: "tritanopia",
      label: "Tritanopia (no blue cones)",
      width: nil,
      filter: "url(#xsb-tritanopia)"
    },
    %{
      id: "achromatopsia",
      label: "Achromatopsia (no color)",
      width: nil,
      filter: "url(#xsb-achromatopsia)"
    },
    %{id: "blur", label: "Low vision (blur)", width: nil, filter: "blur(1.5px)"}
  ]

  # Machado, Oliveira & Fernandes (2009), severity 1.0, linear RGB
  @cvd %{
    "protanopia" =>
      "0.152286 1.052583 -0.204868 0 0 0.114503 0.786281 0.099216 0 0 -0.003882 -0.048116 1.051998 0 0 0 0 0 1 0",
    "deuteranopia" =>
      "0.367322 0.860646 -0.227968 0 0 0.280085 0.672501 0.047413 0 0 -0.011820 0.042940 0.968881 0 0 0 0 0 1 0",
    "tritanopia" =>
      "1.255528 -0.076749 -0.178779 0 0 -0.078411 0.930809 0.147602 0 0 0.004733 0.691367 0.303900 0 0 0 0 0 1 0",
    "achromatopsia" =>
      "0.2126 0.7152 0.0722 0 0 0.2126 0.7152 0.0722 0 0 0.2126 0.7152 0.0722 0 0 0 0 0 1 0"
  }

  def mount(_params, _session, socket, opts) do
    backend = Keyword.fetch!(opts, :backend)
    [story | _] = stories = stories(backend)

    {:ok,
     socket
     |> assign(
       backend: backend,
       storybook_path: Keyword.get(opts, :storybook_path, "/storybook"),
       stories: stories,
       view: :sounds
     )
     |> select(story, nil)}
  end

  def handle_event("select", %{"story" => story} = params, socket) do
    true = story in socket.assigns.stories
    {:noreply, select(socket, story, params["variation"])}
  end

  def handle_event("view", %{"view" => view}, socket) do
    {:noreply, assign(socket, view: String.to_existing_atom(view))}
  end

  # In dev, storybook recompiles a story file on every load_story/1 call (50-350ms
  # each), so only the selected story is loaded; the list comes from the sources.
  defp stories(backend) do
    content_path = backend.config(:content_path, nil)

    for entry <- backend.leaves(),
        source = File.read!(Path.join(content_path, entry.path <> ".story.exs")),
        source =~ ~r/use PhoenixStorybook\.Story,\s*:(live_)?component\b/ do
      entry.path
    end
  end

  def render(assigns) do
    assigns =
      assign(assigns,
        views: @views,
        stress: @stress,
        cvd: @cvd,
        src: "#{assigns.storybook_path}/iframe#{assigns.story}?variation_id=#{assigns.variation}"
      )

    ~H"""
    <div class="xsb-inspector">
      <style>
        .xsb-inspector { font-family: Inter, ui-sans-serif, system-ui, sans-serif; line-height: 1.4; color: #1d1d1f; background: #fff; color-scheme: light; }
        .xsb-inspector form { display: flex; gap: 1rem; flex-wrap: wrap; margin-bottom: 1rem; }
        .xsb-inspector label { display: flex; flex-direction: column; font-weight: 600; gap: .25rem; }
        .xsb-inspector select { font: inherit; padding: .3rem; border: 1px solid #767676; border-radius: .25rem; }
        .xsb-views { display: flex; gap: .5rem; margin-bottom: 1rem; }
        .xsb-views button { font: inherit; padding: .35rem .8rem; border: 1px solid #1a5fb4; border-radius: .25rem; background: #fff; color: #1a5fb4; cursor: pointer; }
        .xsb-views button[aria-pressed=true] { background: #1a5fb4; color: #fff; }
        .xsb-views button:focus-visible, .xsb-inspector select:focus-visible { outline: 3px solid #1a5fb4; outline-offset: 2px; }
        .xsb-split { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 1.5rem; align-items: start; }
        .xsb-inspector iframe { width: 100%; height: 200px; border: 1px dashed #767676; background: #fff; }
        .xsb-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(340px, 1fr)); gap: 1.5rem; }
        .xsb-grid figure { margin: 0; }
        .xsb-grid figcaption { font-weight: 600; margin-bottom: .25rem; }
        .xsb-inspector ol { padding-left: 1.5rem; margin: .25rem 0; }
        .xsb-problem strong { color: #b00020; }
        .xsb-ok, .xsb-inspector [data-problems="0"] { color: #116329; font-weight: 600; }
        .xsb-inspector [role=status]:not([data-problems="0"]) { color: #b00020; font-weight: 600; }
      </style>
      <svg aria-hidden="true" width="0" height="0" style="position: absolute">
        <defs>
          <filter :for={{id, matrix} <- @cvd} id={"xsb-#{id}"}>
            <feColorMatrix type="matrix" values={matrix} />
          </filter>
        </defs>
      </svg>

      <form phx-change="select">
        <label>
          Component
          <select name="story">
            {Phoenix.HTML.Form.options_for_select(@stories, @story)}
          </select>
        </label>
        <label>
          Variation
          <select name="variation">
            {Phoenix.HTML.Form.options_for_select(@ids, @variation)}
          </select>
        </label>
      </form>

      <div class="xsb-views" role="group" aria-label="View">
        <button
          :for={{id, label} <- @views}
          type="button"
          phx-click="view"
          phx-value-view={id}
          aria-pressed={to_string(@view == id)}
        >
          {label}
        </button>
      </div>

      <div :if={@view in [:sounds, :focus]} class="xsb-split">
        <iframe
          id={"xsb-frame-#{@view}"}
          phx-hook="XsbFrame"
          data-mode={@view}
          data-output={"xsb-out-#{@view}"}
          data-status={"xsb-status-#{@view}"}
          srcdoc={@srcdoc}
          src={!@srcdoc && @src}
          title={"#{@story} #{@variation}"}
        >
        </iframe>
        <section>
          <h2>{if @view == :sounds, do: "What a screen reader hears", else: "Tab order"}</h2>
          <p id={"xsb-status-#{@view}"} role="status"></p>
          <div id={"xsb-out-#{@view}"} phx-update="ignore"></div>
        </section>
      </div>

      <div :if={@view == :stress} class="xsb-grid">
        <figure :for={s <- @stress}>
          <figcaption id={"xsb-cap-#{s.id}"}>{s.label}</figcaption>
          <iframe
            id={"xsb-frame-#{s.id}"}
            phx-hook="XsbFrame"
            data-mode={if s.id in ["reflow", "text-200", "text-spacing"], do: s.id, else: "plain"}
            data-output={"xsb-out-#{s.id}"}
            srcdoc={@srcdoc}
            src={!@srcdoc && @src}
            title={"#{s.label}: #{@story} #{@variation}"}
            style={"#{s.width && "width: #{s.width}px;"} #{s.filter && "filter: #{s.filter};"}"}
          >
          </iframe>
          <div id={"xsb-out-#{s.id}"} phx-update="ignore"></div>
        </figure>
      </div>
    </div>
    """
  end

  defp select(socket, story, variation) do
    {:ok, mod} = socket.assigns.backend.load_story(story)
    ids = Enum.map(mod.variations(), &to_string(&1.id))
    variation = if variation in ids, do: variation, else: hd(ids)

    assign(socket,
      story: story,
      ids: ids,
      variation: variation,
      srcdoc: srcdoc(socket.assigns.backend, socket.assigns.storybook_path, mod, variation)
    )
  end

  # Rendering the variation here skips storybook's iframe page (its JS bundle and a
  # LiveView connection), which was most of the wait on every change. The cost: the
  # component is static, so JS hooks don't run. Anything that can't render without a
  # socket returns nil and falls back to the iframe page.
  defp srcdoc(backend, storybook_path, mod, variation_id) do
    variation = Enum.find(mod.variations(), &(to_string(&1.id) == variation_id))

    html =
      backend
      |> PhoenixStorybook.Rendering.RenderingContext.build(mod, variation, %{})
      |> PhoenixStorybook.Rendering.ComponentRenderer.render()
      |> to_iodata()

    # The same head and body storybook's own iframe page uses, so components look alike.
    css = backend.config(:css_path, nil)
    theme = backend.config(:theme_path, nil)

    IO.iodata_to_binary([
      ~s(<!doctype html><html lang="en"><head><meta charset="utf-8">),
      ~s(<link rel="stylesheet" href="#{storybook_path}/assets/css/phoenix_storybook.css">),
      if(css, do: ~s(<style>@import "#{css}" layer(app\);</style>), else: ""),
      if(theme, do: ~s(<style>@import "#{theme}";</style>), else: ""),
      ~s(</head><body class="psb-sandbox #{backend.config(:sandbox_class, nil)}" style="margin: 0;">),
      html,
      "</body></html>"
    ])
  rescue
    _ -> nil
  end

  defp to_iodata(%Phoenix.LiveView.Rendered{} = rendered),
    do: Phoenix.HTML.Safe.to_iodata(rendered)

  defp to_iodata(iodata), do: iodata
end
