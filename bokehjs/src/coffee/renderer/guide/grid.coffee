
define [
  "underscore",
  "common/has_parent",
  "common/collection",
  "renderer/properties",
  "common/plot_widget",
], (_, HasParent, Collection, Properties, PlotWidget) ->

  line_properties = Properties.line_properties

  class GridView extends PlotWidget
    initialize: (attrs, options) ->
      super(attrs, options)
      @grid_props = new line_properties(@, null, 'grid_')
      @x_range_name = @mget('x_range_name')
      @y_range_name = @mget('y_range_name')

    render: () ->
      ctx = @plot_view.canvas_view.ctx

      ctx.save()
      @_draw_grids(ctx)
      ctx.restore()

    bind_bokeh_events: () ->
      @listenTo(@model, 'change', @request_render)

    _draw_grids: (ctx) ->
      if not @grid_props.do_stroke
        return
      [xs, ys] = @mget('grid_coords')
      @grid_props.set(ctx, @)
      for i in [0...xs.length]
        [sx, sy] = @plot_view.map_to_screen(xs[i], "data", ys[i], "data", @x_range_name, @y_range_name)
        ctx.beginPath()
        ctx.moveTo(Math.round(sx[0]), Math.round(sy[0]))
        for i in [1...sx.length]
          ctx.lineTo(Math.round(sx[i]), Math.round(sy[i]))
        ctx.stroke()
      return

  class Grid extends HasParent
    default_view: GridView
    type: 'Grid'

    initialize: (attrs, options)->
      super(attrs, options)

      @register_property('computed_bounds', @_bounds, false)
      @add_dependencies('computed_bounds', this, ['bounds'])

      @register_property('grid_coords', @_grid_coords, false)
      @add_dependencies('grid_coords', this, ['computed_bounds', 'dimension', 'ticker'])

      @register_property('ranges', @_ranges, true)

    _ranges: () ->
      i = @get('dimension')
      j = (i + 1) % 2
      frame = @get('plot').get('frame')
      ranges = [
        frame.get('x_ranges')[@get('x_range_name')],
        frame.get('y_ranges')[@get('y_range_name')]
      ]
      return [ranges[i], ranges[j]]

     _bounds: () ->
      [range, cross_range] = @get('ranges')

      user_bounds = @get('bounds') ? 'auto'
      range_bounds = [range.get('min'), range.get('max')]

      if _.isArray(user_bounds)
        start = Math.min(user_bounds[0], user_bounds[1])
        end = Math.max(user_bounds[0], user_bounds[1])
        if start < range_bounds[0]
          start = range_bounds[0]
        else if start > range_bounds[1]
          start = null
        if end > range_bounds[1]
          end = range_bounds[1]
        else if end < range_bounds[0]
          end = null
      else
        [start, end] = range_bounds

      return [start, end]

    _grid_coords: () ->
      i = @get('dimension')
      j = (i + 1) % 2
      [range, cross_range] = @get('ranges')

      [start, end] = @get('computed_bounds')

      tmp = Math.min(start, end)
      end = Math.max(start, end)
      start = tmp

      ticks = @get('ticker').get_ticks(start, end, range, {}).major

      min = range.get('min')
      max = range.get('max')

      cmin = cross_range.get('min')
      cmax = cross_range.get('max')

      coords = [[], []]
      for ii in [0...ticks.length]
        if ticks[ii] == min or ticks[ii] == max
          continue
        dim_i = []
        dim_j = []
        N = 2
        for n in [0...N]
          loc = cmin + (cmax-cmin)/(N-1) * n
          dim_i.push(ticks[ii])
          dim_j.push(loc)
        coords[i].push(dim_i)
        coords[j].push(dim_j)

      return coords

    defaults: ->
      _.extend {}, super(), {
        x_range_name: "default"
        y_range_name: "default"
      }

    display_defaults: ->
      _.extend {}, super(), {
        level: 'underlay'
        grid_line_color: '#cccccc'
        grid_line_width: 1
        grid_line_alpha: 1.0
        grid_line_join: 'miter'
        grid_line_cap: 'butt'
        grid_line_dash: []
        grid_line_dash_offset: 0
      }

  class Grids extends Collection
     model: Grid

  return {
    "Model": Grid,
    "Collection": new Grids(),
    "View": GridView
  }
