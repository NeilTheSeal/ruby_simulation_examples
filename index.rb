# mandelbrot_gosu.rb
require "gosu"
require "parallel"

WIDTH    = 800
HEIGHT   = 600
MAX_ITER = 100

# 1) Precompute the color palette once
PALETTE = Array.new(MAX_ITER + 1) do |i|
  if i == MAX_ITER
    Gosu::Color.rgb(0, 0, 0)
  else
    v = (255 * i / MAX_ITER).to_i
    Gosu::Color.rgb(v, v, v)
  end
end

class MandelbrotWindow < Gosu::Window
  def initialize
    super(WIDTH, HEIGHT)
    self.caption = "Mandelbrot Viewer (Gosu 1.4.6)"

    @zoom     = 200.0   # pixels per unit
    @offset_x = -2.5    # complex plane origin (real)
    @offset_y = -1.5    # complex plane origin (imag)

    @last_render = Time.now
    @image       = render_mandelbrot
  end

  def update
    moved = false
    pan   = 0.1 / @zoom

    if button_down?(Gosu::KB_LEFT)
      @offset_x -= pan
      moved = true
    end
    if button_down?(Gosu::KB_RIGHT)
      @offset_x += pan
      moved = true
    end
    if button_down?(Gosu::KB_UP)
      @offset_y -= pan
      moved = true
    end
    if button_down?(Gosu::KB_DOWN)
      @offset_y += pan
      moved = true
    end

    if button_down?(Gosu::KB_EQUALS)
      @zoom *= 1.1
      moved = true
    elsif button_down?(Gosu::KB_MINUS)
      @zoom /= 1.1
      moved = true
    end

    # rate-limit redraws to once every 0.2s
    return unless moved && (Time.now - @last_render) > 0.2

    @image       = render_mandelbrot
    @last_render = Time.now
  end

  def draw
    @image.draw(0, 0, 0)
  end

  private

  def render_mandelbrot
    # 2) Hoist locals for speed
    zoom     = @zoom
    inv_zoom = 1.0 / zoom
    ox = @offset_x
    oy = @offset_y
    palette = PALETTE

    # 3) Parallel compute each row of colors
    rows = Parallel.map(0...HEIGHT, in_threads: 8) do |py|
      ci = py * inv_zoom + oy
      (0...WIDTH).map do |px|
        cr = px * inv_zoom + ox
        zr = zi = iter = 0

        while zr * zr + zi * zi <= 4.0 && iter < MAX_ITER
          zr, zi = zr * zr - zi * zi + cr, 2 * zr * zi + ci
          iter  += 1
        end

        palette[iter]
      end
    end

    # 4) Draw the precomputed color grid
    Gosu.render(WIDTH, HEIGHT, retro: true) do
      rows.each_with_index do |row, py|
        row.each_with_index do |color, px|
          draw_rect(px, py, 1, 1, color, 0)
        end
      end
    end
  end
end

MandelbrotWindow.new.show
