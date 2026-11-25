defmodule TripwireWeb.CoreComponents do
  use Phoenix.Component
  use Gettext, backend: TripwireWeb.Gettext

  alias Phoenix.LiveView.JS

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  def translate_error({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(TripwireWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(TripwireWeb.Gettext, "errors", msg, opts)
    end
  end
end
