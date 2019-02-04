library(drake)
library(dplyr)
library(tidyr)
library(showtext)
library(sysfonts)
library(png)
library(grid)
library(yaml)

source("6_visualize/src/create_gif_tasks.R")
source("6_visualize/src/create_gif_makefile.R")
source("6_visualize/src/prep_view_fun.R")
source("6_visualize/src/prep_basemap_fun.R")
source("6_visualize/src/prep_title_fun.R")
source("6_visualize/src/prep_legend_fun.R")
source("6_visualize/src/prep_vertical_legend_fun.R")
source("6_visualize/src/prep_watermark_fun.R")
source("6_visualize/src/prep_gage_sites_fun.R")
source("6_visualize/src/prep_callouts_fun.R")
source("6_visualize/src/combine_animation_frames.R")
source("6_visualize/src/create_animation_frame.R")
source("6_visualize/src/prep_datewheel_fun.R")
source("1_fetch/src/map_utils.R")
pkgconfig::set_config("drake::strings_in_dots" = "literals")

date_step <- seq.Date(from = as.Date("2017-10-01"),
                      to = as.Date("2018-09-30"), by = "day")

date_step <- paste(date_step, "00:00:00")

plan <- drake_plan(
  viz_config = yaml.load_file(file_in('viz_config.yml')),
  dates_config = viz_config[['dates']],
  date_display_tz = viz_config[['date_display_tz']],
  intro_config = viz_config[['intro']],
  legend_cfg = viz_config[["legend_cfg"]],
  datewheel_cfg = viz_config[["datewheel_cfg"]],
  font_abel = font_add_google('Abel', 'abel'),
  font_oswald = font_add_google('Oswald', 'Oswald'),
  component_placement = viz_config[['component_placement']],
  watermark_x_pos = component_placement[['watermark_x_pos']],
  watermark_y_pos = component_placement[['watermark_y_pos']],
  legend_x_pos = component_placement[['legend_x_pos']],
  legend_y_pos = component_placement[['legend_y_pos']],
  sites_color_palette = viz_config[['sites_color_palette']],
  outro_placement = component_placement[['outro']],
  view_cfg = viz_config['background_col'],
  view_config = viz_config[c('bbox', 'projection', 'width', 'height')],
  view_polygon = as_view_polygon(view_config),
  view_fun = prep_view_fun(view_polygon, view_cfg),
  basemap_cfg = viz_config[['basemap']],
  basemap_fun = prep_basemap_fun(states_shifted, basemap_cfg),
  title_cfg = viz_config[['title_cfg']],
  percentiles = viz_config[['percentiles']],
  title_fun = prep_title_fun(title_cfg),
  legend_fun = prep_vertical_legend_fun(
      percentiles_str = percentiles,
      sites_color_palette = sites_color_palette,
      x_pos = legend_x_pos,
      y_pos = legend_y_pos,
      legend_cfg = legend_cfg),
  watermark_fun = prep_watermark_fun(file_in('6_visualize/in/usgs_logo_black.png'),
                                x_pos = watermark_x_pos,
                                y_pos = watermark_y_pos),
  timestep_frame_config = viz_config[c('width','height')],
  timestep_frame_step = viz_config[['frame_step']],
  callouts_cfg = viz_config[['callouts']],
  datewheel_fun = prep_datewheel_fun(date_step[date__],
                                     viz_config,
                                     dates_config,
                                     datewheel_cfg),
  gage_sites_fun = prep_gage_sites_fun(percentile_color_data_ind = file_out('2_process/out/dv_stat_styles.rds.ind'),
                                       sites_sp = site_locations_shifted,
                                       dateTime=date_step[date__]),
  callouts_fun = prep_callouts_fun(callouts_cfg = callouts_cfg,
                                   dateTime=date_step[date__]),
  frame = create_animation_frame(
    png_file=file_out("6_visualize/tmp/frame_date__.png"),
    config=timestep_frame_config,
    view_fun,
    basemap_fun,
    title_fun,
    legend_fun,
    watermark_fun,
    datewheel_fun_date__,
    gage_sites_fun_date__,
    callouts_fun_date__),
  animation_cfg = viz_config[['animation']]

)

# step_index <- 1:length(date_step)
step_index <- 1:100

full_plan <- evaluate_plan(
  plan,
  rules = list(
    date__ = step_index
  )
)

frames <- full_plan %>%
  gather_by(prefix = "frames",gather = "c",
            filter = grepl("6_visualize/tmp", command))
# frames$command[39]
# frames$target[39]

final_step <- drake_plan(
  year_in_review = combine_animation_frames(
    gif_file=file_out("6_visualize/out/year_in_review.mp4"),
    animation_cfg=animation_cfg, frames)
)

really_full_plan <- bind_plans(
  frames,
  final_step
)


# make(full_plan)
config <- drake_config(really_full_plan)
vis_drake_graph(config)
sankey_drake_graph(config)

scipiper::scmake(remake_file = "2_process.yml")
site_locations_shifted <- scipiper::scmake(target_names = "site_locations_shifted")
states_shifted <- scipiper::scmake(target_names = "states_shifted")

make(full_plan)

system.time({
  make(full_plan)
})
