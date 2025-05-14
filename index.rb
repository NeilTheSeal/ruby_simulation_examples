# mandelbrot_gosu.rb
require "gosu"

WIDTH     = 800
HEIGHT    = 600
MAX_ITER  = 100

class MandelbrotWindow < Gosu::Window
  def initialize
    super(WIDTH, HEIGHT)
    self.caption = "Mandelbrot Viewer (Gosu 1.4.6)"

    @zoom     = 200.0   # pixels per unit
    @offset_x = -2.5    # complex plane origin (real)
    @offset_y = -1.5    # complex plane origin (imag)

    # Pre-render once
    @image = render_mandelbrot
  end

  def update
    moved = false
    pan = 0.1 / @zoom

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

    # Zoom in with '=' key
    if button_down?(Gosu::KB_EQUALS)
      @zoom *= 1.1
      moved = true

    # Zoom out with '-' key
    elsif button_down?(Gosu::KB_MINUS)
      @zoom /= 1.1
      moved = true
    end

    # Only re-render when view parameters change
    @image = render_mandelbrot if moved
  end

  def draw
    @image.draw(0, 0, 0)
  end

  private

  def render_mandelbrot
    Gosu.render(WIDTH, HEIGHT, retro: true) do
      (0...WIDTH).each do |px|
        (0...HEIGHT).each do |py|
          # map pixel → complex plane
          cr = px / @zoom + @offset_x
          ci = py / @zoom + @offset_y

          zr = zi = 0.0
          iter = 0

          while zr * zr + zi * zi <= 4.0 && iter < MAX_ITER
            zr, zi = zr * zr - zi * zi + cr, 2 * zr * zi + ci
            iter += 1
          end

          c = iter == MAX_ITER ? 0 : (255 * iter / MAX_ITER).to_i
          color = Gosu::Color.rgb(c, c, c)
          draw_rect(px, py, 1, 1, color, 0)
        end
      end
    end
  end
end

MandelbrotWindow.new.show
