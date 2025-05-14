# streamlines.rb
# Simulate fluid flow around a sphere (streamlines) using Gosu

require "gosu"

# Window dimensions
WIDTH  = 900
HEIGHT = 900

# Fluid and simulation parameters
DIAMETER   = 1.0
VISCOSITY  = 0.00089 # Pa·s (dynamic viscosity of water at 20°C)
DENSITY    = 1000.0
VELOCITY   = 0.00001
LINE_LENGTH = 9 # arrow scale
MIN_LINE_LENGTH = 4 # minimum arrow length
CANVAS_SIZE = 3.0 # coordinate span [-3,3]

class FluidSimulator < Gosu::Window
  def initialize
    super(WIDTH, HEIGHT)
    self.caption = "Fluid Flow Around Sphere"

    # center and radius in pixels
    @cx = WIDTH / 2.0
    @cy = HEIGHT / 2.0
    @r  = (WIDTH / CANVAS_SIZE) / 2.0

    # precompute circle perimeter points
    @circle_pts = (0...64).map do |i|
      theta = i * 2 * Math::PI / 64
      [@cx + @r * Math.cos(theta), @cy + @r * Math.sin(theta)]
    end

    @viscosity = VISCOSITY
    @velocity  = VELOCITY
    @font      = Gosu::Font.new(20)
  end

  def re
    DENSITY * @velocity * DIAMETER / @viscosity
  end

  def update
    # Adjust velocity with Up/Down
    if button_down?(Gosu::KB_UP)
      @velocity *= 1.01
    elsif button_down?(Gosu::KB_DOWN)
      @velocity = [0.000001, @velocity / 1.01].max
    end
    # Adjust viscosity with Left/Right
    if button_down?(Gosu::KB_RIGHT)
      @viscosity *= 1.01
    elsif button_down?(Gosu::KB_LEFT)
      @viscosity = [0.000001, @viscosity / 1.01].max
    end
  end

  def draw
    # grey background
    Gosu.draw_rect(0, 0, WIDTH, HEIGHT, Gosu::Color.new(0xffcccccc), 0)
    draw_sphere
    draw_field
    draw_text_overlay
  end

  private

  def draw_text_overlay
    text    = format("U: %.5f m/s  μ: %.5f Pa·s", @velocity, @viscosity)
    padding = 4
    x = 10
    y = 10
    w       = @font.text_width(text)
    h       = @font.height

    # 1) white background rectangle (z=0)
    Gosu.draw_rect(
      x - padding,         # left
      y - padding,         # top
      w + padding * 2,       # width
      h + padding * 2,       # height
      Gosu::Color::WHITE,  # color
      0                    # z-order
    )

    # 2) then draw the text on top (z=1)
    @font.draw_text(
      text,
      x,
      y,
      1,                    # z-order above the rect
      1.0, 1.0,             # scale
      Gosu::Color::BLACK    # text color
    )
  end

  # draw sphere as polygon
  def draw_sphere
    # 1) fill the circle white with a triangle‐fan
    @circle_pts.each_with_index do |(x1, y1), i|
      x2, y2 = @circle_pts[(i + 1) % @circle_pts.size]
      Gosu.draw_triangle(
        @cx, @cy, Gosu::Color::WHITE,
        x1,    y1, Gosu::Color::WHITE,
        x2,    y2, Gosu::Color::WHITE,
        0
      )
    end

    # 2) optional: draw a thin black outline on top
    @circle_pts.each_with_index do |(x1, y1), i|
      x2, y2 = @circle_pts[(i + 1) % @circle_pts.size]
      Gosu.draw_line(x1, y1, Gosu::Color::BLACK,
                     x2, y2, Gosu::Color::BLACK,
                     1)
    end
  end

  # draw vector field arrows
  def draw_field
    color = Gosu::Color::BLACK
    step = 20
    (0...WIDTH).step(step) do |px|
      (0...HEIGHT).step(step) do |py|
        # map to fluid coords x,y
        x = ((px - @cx) / WIDTH)  * 2 * CANVAS_SIZE
        y = ((py - @cy) / HEIGHT) * 2 * CANVAS_SIZE
        # skip inside sphere
        next if x * x + y * y <= 1.05

        u = velocity_vector(re, x, y)
        # endpoints
        x1 = px - LINE_LENGTH * u[0]
        y1 = py - LINE_LENGTH * u[1]
        x2 = px + LINE_LENGTH * u[0]
        y2 = py + LINE_LENGTH * u[1]

        # draw shaft
        Gosu.draw_line(x1, y1, color, x2, y2, color, 0)

        # draw arrowhead
        draw_arrowhead(x2, y2, u, color)
      end
    end
  end

  # arrowhead at (x2,y2) pointed along u
  def draw_arrowhead(x2, y2, u, color)
    theta = Math.atan2(u[1], u[0])
    head_len = 6
    head_w   = 2
    # base point of arrowhead
    bx = x2 - head_len * Math.cos(theta)
    by = y2 - head_len * Math.sin(theta)
    # wing points
    wx1 = bx +  head_w * Math.sin(theta)
    wy1 = by -  head_w * Math.cos(theta)
    wx2 = bx -  head_w * Math.sin(theta)
    wy2 = by +  head_w * Math.cos(theta)
    Gosu.draw_triangle(x2, y2, color,
                       wx1, wy1, color,
                       wx2, wy2, color,
                       0)
  end

  # compute U(re, x, y) as [u_x, u_y] in normalized units,
  # but with a minimum length so arrows are at least 5px long
  def velocity_vector(re, x, y)
    # --- your existing polar→cartesian code ---
    r  = Math.sqrt(x * x + y * y)
    th = Math.atan2(y, x)
    ur, ut = ur0(re, r, th) # returns [ur, uθ]
    u_x =  ur * Math.cos(th) - ut * Math.sin(th)
    u_y =  ur * Math.sin(th) + ut * Math.cos(th)

    # --- now clamp to a minimum magnitude ---
    mag     = Math.hypot(u_x, u_y)
    min_u   = MIN_LINE_LENGTH / LINE_LENGTH # required minimum in normalized units
    if mag > 0 && mag < min_u
      scale = min_u / mag
      u_x   *= scale
      u_y   *= scale
    end

    [u_x, u_y]
  end

  # radial/tangential from Ur0 formulas
  def ur0(re, r, th)
    cos = Math.cos(th)
    sin = Math.sin(th)
    r2  = 1.0 / (r * r)
    r3  = r2 / r
    r4  = r2 * r2
    r5  = r2 * r3
    r6  = r3 * r3
    a1 = A1(re)
    a2 = A2(re)
    a3 = A3(re)
    a4 = A4(re)
    b1 = B1(re)
    b2 = B2(re)
    b3 = B3(re)
    b4 = B4(re)
    # ur, utheta
    [(1 + 2 * (a1 * r3 + a2 * r4 + a3 * r5 + a4 * r6)) * cos + (b1 * r3 + b2 * r4 + b3 * r5 + b4 * r6) * (3 * cos * cos - 1),
     (-1 + a1 * r3 + 2 * a2 * r4 + 3 * a3 * r5 + 4 * a4 * r6) * sin + (b1 * r3 + 2 * b2 * r4 + 3 * b3 * r5 + 4 * b4 * r6) * sin * cos]
  end

  # coefficient functions, ported directly
  def A1(re)
    r = re**2
    c1 = ((2.7391417851819595e11 + r * (2.1079461581884886e9 + r * (3.609662630935375e4 + 3.3644813668472526 * r))) +
          100 * re * Math.sqrt(1.2735686181258997e17 + r * (4.388552339698552e14 + r * (1.776934907636144e10 + r * (1.1512716122770787e6 + 57.95077149780876 * r)))))**(1 / 3.0)
    c2 = 100 * (1.3636505692563244 * (r - 85.79134132307645**2) * (r - 50.51906885775793**2))
    c3 = c2 / c1 + 60.73294576824199 * c1
    c4 = Math.sqrt(41.715270532950086 + (-788_846.5185368055 + c3) / r)
    ((c4 - Math.sqrt(83.43054106590017 + ((5.686988475331831e7 + 1474.4854794642922 * r) / (r * c4) - (1.5776930370736108e6 + c3) / r))) / 2 - 2.8781637206259836)
  end

  def A2(re)
    -15.0 / 29 * (8 + 5 * A1(re))
  end

  def A3(re)
    9.0 / 29 * (17 + 7 * A1(re))
  end

  def A4(re)
    -1.0 / 58 * (95 + 34 * A1(re))
  end

  def B1(re)
    -1 * (44.689656 + 9.931035 * A1(re)) / ((0.011713 - 0.002546 * A1(re)) * re)
  end

  def B2(re)
    -23.0 / 9 * B1(re)
  end

  def B3(re)
    19.0 / 9 * B1(re)
  end

  def B4(re)
    -5.0 / 9 * B1(re)
  end
end

FluidSimulator.new.show
