# mandelbrot_gosu_ractors.rb
require "gosu"
require "etc"

WIDTH        = 400
HEIGHT       = 300
MAX_ITER     = 100
RACTOR_COUNT = Etc.nprocessors # one Ractor per core

# 1) Precompute the color palette once (shareable)
PALETTE = Array.new(MAX_ITER + 1) do |i|
  if i == MAX_ITER
    Gosu::Color.rgb(0, 0, 0)
  else
    v = (255 * i / MAX_ITER).to_i
    Gosu::Color.rgb(v, v, v)
  end
end.freeze

class MandelbrotWindow < Gosu::Window
  def initialize
    super(WIDTH, HEIGHT)
    self.caption = "Mandelbrot Viewer with Ractors"

    @zoom     = 100.0
    @offset_x = -2.5
    @offset_y = -1.5

    @last_render = Time.now

    # 2) Build a persistent pool of Ractors
    @workers = Array.new(RACTOR_COUNT) do
      Ractor.new do
        loop do
          slice, zoom, inv_zoom, ox, oy = Ractor.receive
          # Compute a block of rows → array of [row0, row1, …]
          result = slice.map do |py|
            ci = py * inv_zoom + oy
            Array.new(WIDTH) do |px|
              cr = px * inv_zoom + ox
              zr = zi = 0.0
              iter = 0
              while zr * zr + zi * zi <= 4.0 && iter < MAX_ITER
                zr, zi = zr * zr - zi * zi + cr, 2 * zr * zi + ci
                iter += 1
              end
              iter
            end
          end
          Ractor.yield(result)
        end
      end
    end

    @image = render_mandelbrot

    @font = Gosu::Font.new(20)
  end

  def update
    moved = false

    inv_zoom = 1.0 / @zoom
    pan_pixels = 10
    pan = pan_pixels * inv_zoom

    moved ||= adjust(:@offset_x, -pan) if button_down?(Gosu::KB_LEFT)
    moved ||= adjust(:@offset_x,  pan) if button_down?(Gosu::KB_RIGHT)
    moved ||= adjust(:@offset_y, -pan) if button_down?(Gosu::KB_UP)
    moved ||= adjust(:@offset_y,  pan) if button_down?(Gosu::KB_DOWN)

    # ——— centered zoom ———
    factor = nil
    factor = 1.1 if button_down?(Gosu::KB_EQUALS) # zoom in
    factor = 1.0 / 1.1 if button_down?(Gosu::KB_MINUS) # zoom out

    if factor
      # 1) World‐coords at canvas center before zoom
      cx = WIDTH  / 2.0
      cy = HEIGHT / 2.0
      center_re = @offset_x + cx * inv_zoom
      center_im = @offset_y + cy * inv_zoom

      # 2) Apply zoom
      @zoom *= factor
      new_inv = 1.0 / @zoom

      # 3) Recompute offsets so (cx,cy) maps back to (center_re, center_im)
      @offset_x = center_re - cx * new_inv
      @offset_y = center_im - cy * new_inv

      moved = true
    end
    # ————————————

    # rate‑limit and redraw
    return unless moved && (Time.now - @last_render) > 0.2

    @image       = render_mandelbrot
    @last_render = Time.now
  end

  def draw
    @image.draw(0, 0, 0)
  end

  private

  # Helper to adjust an ivar and return true for “moved”
  def adjust(var, delta)
    instance_variable_set(var, instance_variable_get(var) + delta)
    true
  end

  def render_mandelbrot
    # Hoist locals
    zoom     = @zoom
    inv_zoom = 1.0 / zoom
    ox = @offset_x
    oy = @offset_y

    # Dispatch & collect iteration counts as before…
    slice_size = (HEIGHT.to_f / RACTOR_COUNT).ceil
    slices     = (0...HEIGHT).each_slice(slice_size).to_a
    slices.zip(@workers).each { |slice, w| w.send([slice, zoom, inv_zoom, ox, oy]) }
    rows_iters = @workers.flat_map(&:take) # [[iter,…], …]

    # === build one giant RGBA blob ===
    total_bytes = WIDTH * HEIGHT * 4
    blob = "\0".b * total_bytes
    idx = 0

    rows_iters.each do |row|
      row.each do |iter|
        color = PALETTE[iter]
        blob.setbyte(idx,     color.red)
        blob.setbyte(idx + 1, color.green)
        blob.setbyte(idx + 2, color.blue)
        blob.setbyte(idx + 3, color.alpha)
        idx += 4
      end
    end

    # Create a single image and return it
    Gosu::Image.from_blob(WIDTH, HEIGHT, blob)
  end
end

MandelbrotWindow.new.show
