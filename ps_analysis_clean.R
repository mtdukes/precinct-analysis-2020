#2020 precinct sort analysis
#code used to analyze the precinct sort data from 2020 and 2016


# Setting up --------------------------------------------------------------


#set our working directory
setwd("~/Dropbox/projects/newsobserver/precinct_sort/data")

#load libraries
library(tidyverse)
library(sf)
library(janitor)
library(knitr)
library(stringr)
library(scales)


# Loading data ------------------------------------------------------------


#Data through the State Board of Elections FTP site
#https://dl.ncsbe.gov/?prefix=ENRS/2020_11_03/results_precinct_sort/
#https://dl.ncsbe.gov/?prefix=ENRS/2016_11_08/results_precinct_sort/
#all files downloaded from SBE site using:
#wget -i all_precincts2020.txt
#wget -i all_precincts2016.txt

#create a list of files to download
county_files2020 <- list.files(path = './county_files2020', full.names = TRUE)
county_files2016 <- list.files(path = './county_files2016', full.names = TRUE)

#load plyr for this step
library(plyr)
#import our files from 2020
precinct_sort2020 <- ldply(county_files2020, read_tsv, na='', col_types = cols(
  county_id = col_double(),
  county = col_character(),
  election_dt = col_date(format = '%m/%d/%Y'),
  result_type_lbl = col_character(),
  result_type_desc = col_character(),
  contest_id = col_double(),
  contest_title = col_character(),
  contest_party_lbl = col_character(),
  contest_vote_for = col_double(),
  precinct_code = col_character(),
  precinct_name = col_character(),
  candidate_id = col_double(),
  candidate_name = col_character(),
  candidate_party_lbl = col_character(),
  group_num = col_double(),
  group_name = col_character(),
  voting_method_lbl = col_character(),
  voting_method_rslt_desc = col_character(),
  vote_ct = col_double()
))

#import our files from 2016
precinct_sort2016 <- ldply(county_files2016, read_tsv, na='', col_types = cols(
  county_id = col_double(),
  county = col_character(),
  election_dt = col_date(format = '%m/%d/%Y'),
  result_type_lbl = col_character(),
  result_type_desc = col_character(),
  contest_id = col_double(),
  contest_title = col_character(),
  contest_party_lbl = col_character(),
  contest_vote_for = col_double(),
  precinct_code = col_character(),
  precinct_name = col_character(),
  candidate_id = col_double(),
  candidate_name = col_character(),
  candidate_party_lbl = col_character(),
  group_num = col_double(),
  group_name = col_character(),
  voting_method_lbl = col_character(),
  voting_method_rslt_desc = col_character(),
  vote_ct = col_double()
))
#unload plyr because it mucks with dplyr
detach("package:plyr", unload=TRUE)

#clean up that 2016 precinct code so it matches our 2020 data
precinct_sort2016 <- precinct_sort2016 %>%
  separate(precinct_name, c('precinct_code',NA), sep = '_', extra='drop', fill = 'right', remove = FALSE) %>% 
  relocate(precinct_code, .after = precinct_cd)

#precinct data sourced from
#https://dl.ncsbe.gov/?prefix=ShapeFiles/Precinct/

#load the precinct shapefile for 2020
nc_precincts <- st_read('precincts2020/SBE_PRECINCTS_20201018.shp')
names(nc_precincts)

#load the precinct shapefile for 2016
nc_precincts2016 <- st_read('precincts2016/Precincts.shp')
names(nc_precincts2016)

#strip out just the data for the 2020 precinct shapefile
#to run some of our queries/table views faster
nc_precincts_data <- as.data.frame(nc_precincts) %>% 
  select(-geometry)

#strip out just the data for the 2016 precinct shapefile
#to run some of our queries/table views faster
nc_precincts_data2016 <- as.data.frame(nc_precincts2016) %>% 
  select(-geometry)


# Gut checks --------------------------------------------------------------


#sum up the votes for president to make sure we got it all.
#5,535,363 calculated vs 5,524,802 on the dashboard
precinct_sort2020 %>%
  filter(contest_title == 'US PRESIDENT') %>%
  summarize(total = sum(vote_ct))

#and for 2016
#4,770,594 calculated vs. 4,741,564 on the dashboard
precinct_sort2016 %>%
  filter(contest_title == 'US PRESIDENT') %>%
  summarize(total = sum(vote_ct))

#3,065 precincts total in the sort data for 2020
#this includes administrative precincts
precinct_sort2020 %>% 
  distinct(county, precinct_code) %>% 
  nrow()

#3,204 precincts total in the sort data for 2016
#this includes administrative precincts
precinct_sort2016 %>% 
  distinct(county, precinct_code) %>% 
  nrow()

#2,659 precincts in the 2020 shapefile data
nc_precincts %>% 
  distinct(county_nam, prec_id)

#2,704 precincts in the 2016 shapefile data
nc_precincts2016 %>% 
  distinct(COUNTY_NAM, PREC_ID)

#3,065 precincts for calculating biden's margin of win/loss
#and a total of 5,443,283 votes for Trump/Biden
#(let's switch this later to the trump margin for consistency)
precinct_sort2020 %>% 
  filter(contest_title == 'US PRESIDENT') %>% 
  filter(candidate_name == 'Joseph R. Biden' | candidate_name == 'Donald J. Trump') %>%
  group_by(county, precinct_code) %>%
  summarize(total_dr = sum(vote_ct)) %>% 
  left_join(precinct_sort2020 %>% 
              filter(contest_title == 'US PRESIDENT') %>% 
              filter(candidate_name == 'Joseph R. Biden') %>%
              group_by(county, precinct_code) %>%
              summarize(biden_votes = sum(vote_ct)),
            by = c('county','precinct_code')
  ) %>% 
  left_join(precinct_sort2020 %>% 
              filter(contest_title == 'US PRESIDENT') %>% 
              filter(candidate_name == 'Donald J. Trump') %>%
              group_by(county, precinct_code) %>%
              summarize(trump_votes = sum(vote_ct)),
            by = c('county','precinct_code')
  ) %>% 
  mutate(biden_margin = round(((biden_votes - trump_votes) / total_dr) * 100, digits = 2) ) %>% 
  arrange(desc(biden_margin)) %>% 
  #nrow() %>% 
  adorn_totals() %>% 
  tail(1) %>% 
  kable('simple')

#3,204 precincts for calculating clinton's margin of win/loss
#and a total of 4,552,380 votes for Trump/Clinton
#(let's switch this later to the trump margin for consistency)
precinct_sort2016 %>% 
  filter(contest_title == 'US PRESIDENT') %>% 
  filter(candidate_name == 'Hillary Clinton' | candidate_name == 'Donald J. Trump') %>%
  group_by(county, precinct_code) %>%
  summarize(total_dr = sum(vote_ct)) %>% 
  left_join(precinct_sort2016 %>% 
              filter(contest_title == 'US PRESIDENT') %>% 
              filter(candidate_name == 'Hillary Clinton') %>%
              group_by(county, precinct_code) %>%
              summarize(clinton_votes = sum(vote_ct)),
            by = c('county','precinct_code')
  ) %>% 
  left_join(precinct_sort2016 %>% 
              filter(contest_title == 'US PRESIDENT') %>% 
              filter(candidate_name == 'Donald J. Trump') %>%
              group_by(county, precinct_code) %>%
              summarize(trump_votes = sum(vote_ct)),
            by = c('county','precinct_code')
  ) %>% 
  mutate(clinton_margin = round(((clinton_votes - trump_votes) / total_dr) * 100, digits = 2) ) %>% 
  arrange(desc(clinton_margin)) %>%
  #nrow() %>% 
  adorn_totals() %>% 
  tail(1) %>% 
  kable('simple')

#confirm there are zero precincts in the 2020 shapefile
#not matching onto the 2020 vote data
nc_precincts %>%
  mutate(county_nam = toupper(county_nam)) %>% 
  anti_join(
    precinct_sort2020 %>% 
      filter(contest_title == 'US PRESIDENT') %>% 
      filter(candidate_name == 'Joseph R. Biden' | candidate_name == 'Donald J. Trump') %>%
      group_by(county, precinct_code) %>%
      summarize(total_dr = sum(vote_ct)) %>% 
      select(county, precinct_code, total_dr),
    by = c('county_nam' = 'county', 'prec_id' = 'precinct_code' )
  )

#totaling 5,433,237 votes mapped for the 2020 data
#NOTE: using distinct here because of a duplicate 
#Cumberland County precinct in the shapefile (G2C-2')
nc_precincts %>%
  mutate(county_nam = toupper(county_nam)) %>%
  distinct(county_nam, prec_id) %>% 
  left_join(
    precinct_sort2020 %>% 
      filter(contest_title == 'US PRESIDENT') %>% 
      filter(candidate_name == 'Joseph R. Biden' | candidate_name == 'Donald J. Trump') %>%
      group_by(county, precinct_code) %>%
      summarize(total_dr = sum(vote_ct)) %>% 
      select(county, precinct_code, total_dr),
    by = c('county_nam' = 'county', 'prec_id' = 'precinct_code' )
  ) %>% 
  summarize(total_votes = sum(total_dr))

#For 2020, missing 10,046 votes, or 0.18%
#remain located in administrative or nonmatching districts
round(((5443283 - 5433237)/5443283) * 100, digits=2)

#totaling 4,540,458 votes mapped for the 2016 data
#NOTE: using distinct here because of a duplicate 
#Cumberland County precinct in the shapefile  (G2C-2')
nc_precincts2016 %>%
  mutate(COUNTY_NAM = toupper(COUNTY_NAM)) %>%
  distinct(COUNTY_NAM, PREC_ID) %>% 
  left_join(
    precinct_sort2016 %>% 
      filter(contest_title == 'US PRESIDENT') %>% 
      filter(candidate_name == 'Hillary Clinton' | candidate_name == 'Donald J. Trump') %>%
      group_by(county, precinct_code) %>%
      summarize(total_dr = sum(vote_ct)) %>% 
      select(county, precinct_code, total_dr),
    by = c('COUNTY_NAM' = 'county', 'PREC_ID' = 'precinct_code' )
  ) %>% 
  summarize(total_votes = sum(total_dr))

#For 2016, missing 11,922 votes or 0.26%
#remain located in administrative or nonmatching districts
round(((4552380 - 4540458)/4552380) * 100, digits=2)

#407 rows from the 2020 precinct data don't map
#to a 2020 precinct shape, which matches the diff
precinct_sort2020 %>% 
  filter(contest_title == 'US PRESIDENT') %>% 
  filter(candidate_name == 'Joseph R. Biden' | candidate_name == 'Donald J. Trump') %>%
  group_by(county, precinct_code) %>%
  summarize(total_dr = sum(vote_ct)) %>% 
  left_join(
    precinct_sort2020 %>%
      filter(contest_title == 'US PRESIDENT') %>% 
      filter(candidate_name == 'Joseph R. Biden') %>%
      group_by(county, precinct_code) %>%
      summarize(biden_votes = sum(vote_ct)),
    by = c('county','precinct_code')
  ) %>% 
  left_join(
    precinct_sort2020 %>%
      filter(contest_title == 'US PRESIDENT') %>% 
      filter(candidate_name == 'Donald J. Trump') %>%
      group_by(county, precinct_code) %>%
      summarize(trump_votes = sum(vote_ct)),
    by = c('county','precinct_code')
  ) %>% 
  mutate(biden_margin = round(((biden_votes - trump_votes) / total_dr) * 100, digits = 2) ) %>% 
  select(county, precinct_code, biden_margin, total_dr) %>% 
  anti_join(
    nc_precincts %>%
      mutate(county_nam = toupper(county_nam)),
    by = c('county' = 'county_nam', 'precinct_code' = 'prec_id' )
  )

#only 60 precincts with a nonzero value, a total of 10,046 votes in 2020
precinct_sort2020 %>% 
  filter(contest_title == 'US PRESIDENT') %>% 
  filter(candidate_name == 'Joseph R. Biden' | candidate_name == 'Donald J. Trump') %>%
  group_by(county, precinct_code) %>%
  summarize(total_dr = sum(vote_ct)) %>%
  select(county, precinct_code, total_dr) %>% 
  anti_join(
    nc_precincts_data %>%
      mutate(county_nam = toupper(county_nam)),
    by = c('county' = 'county_nam', 'precinct_code' = 'prec_id' )
  ) %>%
  filter(total_dr > 0) %>% 
  arrange(desc(total_dr)) %>% 
  adorn_totals(where = c('row')) %>% 
  kable('simple')

#only 77 precincts with a nonzero value, a total of 11,922 votes in 2016
precinct_sort2016 %>% 
  filter(contest_title == 'US PRESIDENT') %>% 
  filter(candidate_name == 'Hillary Clinton' | candidate_name == 'Donald J. Trump') %>%
  group_by(county, precinct_code) %>%
  summarize(total_dr = sum(vote_ct)) %>%
  select(county, precinct_code, total_dr) %>% 
  anti_join(
    nc_precincts_data2016 %>%
      mutate(county_nam = toupper(COUNTY_NAM)),
    by = c('county' = 'COUNTY_NAM', 'precinct_code' = 'PREC_ID' )
  ) %>%
  filter(total_dr > 0) %>% 
  arrange(desc(total_dr)) %>% 
  adorn_totals(where = c('row')) %>% 
  kable('simple')

#for 2020, roll up the unmapped votes by county
#and calculate a percentage of total votes unmapped
precinct_sort2020 %>% 
  filter(contest_title == 'US PRESIDENT') %>% 
  filter(candidate_name == 'Joseph R. Biden' | candidate_name == 'Donald J. Trump') %>%
  group_by(county, precinct_code) %>%
  summarize(total_dr = sum(vote_ct)) %>%
  select(county, precinct_code, total_dr) %>% 
  anti_join(
    nc_precincts_data %>%
      mutate(county_nam = toupper(county_nam)),
    by = c('county' = 'county_nam', 'precinct_code' = 'prec_id' )
  ) %>%
  filter(total_dr > 0) %>%
  group_by(county) %>%
  summarize(unmapped_votes = sum(total_dr)) %>%
  left_join(
    precinct_sort2020 %>% 
      filter(contest_title == 'US PRESIDENT') %>% 
      filter(candidate_name == 'Joseph R. Biden' | candidate_name == 'Donald J. Trump') %>%
      group_by(county) %>%
      summarize(total_dr_votes = sum(vote_ct)),
    by = 'county'
  ) %>%
  mutate(pct_unmapped = round((unmapped_votes/total_dr_votes) * 100, digits = 2) ) %>% 
  arrange(desc(pct_unmapped)) %>% 
  adorn_totals(where = c('row')) %>% 
  kable('simple')

#issues seem to be:
#WAKE          07-07A                       517 (PRECINCT 07-07A)
#HENDERSON     CV                           456 (CAROLINA VILLAGE)
#BUNCOMBE      681                          356 (681)
#WAKE          01-07A                       238 (PRECINCT 01-07A)
#TOTAL: 1567
#everything else is unsorted provisional/absentee etc

# Mapping -----------------------------------------------------------------


#create a new file that matches up the precinct data from 2016 and 2020
#and calculates raw/pct point margins of victories and their changes
precinct_performance <- nc_precincts %>%
  mutate(county_nam = toupper(county_nam)) %>%
  distinct(county_nam, prec_id, .keep_all = TRUE) %>%
  left_join(
    precinct_sort2020 %>% 
      filter(contest_title == 'US PRESIDENT') %>% 
      filter(candidate_name == 'Joseph R. Biden' | candidate_name == 'Donald J. Trump') %>%
      group_by(county, precinct_code) %>%
      summarize(total_dr = sum(vote_ct)) %>% 
      left_join(
        precinct_sort2020 %>%
          filter(contest_title == 'US PRESIDENT') %>% 
          filter(candidate_name == 'Joseph R. Biden') %>%
          group_by(county, precinct_code) %>%
          summarize(dem_votes = sum(vote_ct)),
        by = c('county','precinct_code')
      ) %>% 
      left_join(
        precinct_sort2020 %>%
          filter(contest_title == 'US PRESIDENT') %>% 
          filter(candidate_name == 'Donald J. Trump') %>%
          group_by(county, precinct_code) %>%
          summarize(gop_votes = sum(vote_ct)),
        by = c('county','precinct_code')
      ) %>% 
      mutate(trump_margin2020 = round(((gop_votes - dem_votes) / total_dr) * 100, digits = 2) ) %>% 
      rename(gop2020 = gop_votes) %>%
      rename(dem2020 = dem_votes) %>%
      select(county, precinct_code, gop2020, dem2020, trump_margin2020),
    by = c('county_nam' = 'county', 'prec_id' = 'precinct_code' )
  ) %>% 
  left_join(
    nc_precincts_data2016 %>%
      mutate(COUNTY_NAM = toupper(COUNTY_NAM)) %>%
      distinct(COUNTY_NAM, PREC_ID, .keep_all = TRUE) %>%
      left_join(
        precinct_sort2016 %>% 
          filter(contest_title == 'US PRESIDENT') %>% 
          filter(candidate_name == 'Hillary Clinton' | candidate_name == 'Donald J. Trump') %>%
          group_by(county, precinct_code) %>%
          summarize(total_dr = sum(vote_ct)) %>% 
          left_join(
            precinct_sort2016 %>% 
              filter(contest_title == 'US PRESIDENT') %>% 
              filter(candidate_name == 'Hillary Clinton') %>%
              group_by(county, precinct_code) %>%
              summarize(dem_votes = sum(vote_ct)),
            by = c('county','precinct_code')
          ) %>% 
          left_join(
            precinct_sort2016 %>% 
              filter(contest_title == 'US PRESIDENT') %>% 
              filter(candidate_name == 'Donald J. Trump') %>%
              group_by(county, precinct_code) %>%
              summarize(gop_votes = sum(vote_ct)),
            by = c('county','precinct_code')
          ) %>% 
          mutate(trump_margin2016 = round(((gop_votes - dem_votes) / total_dr) * 100, digits = 2) ) %>%
          rename(gop2016 = gop_votes) %>%
          rename(dem2016 = dem_votes) %>%
          select(county, precinct_code, gop2016, dem2016, trump_margin2016),
        by = c('COUNTY_NAM' = 'county', 'PREC_ID' = 'precinct_code' )
      ) %>% 
      select(COUNTY_NAM, PREC_ID, gop2016, dem2016, trump_margin2016),
    by = c('county_nam' = 'COUNTY_NAM', 'prec_id' = 'PREC_ID')
  ) %>% 
  mutate(trump_pickup = trump_margin2020 - trump_margin2016) %>% 
  relocate(trump_pickup, .after = trump_margin2016) %>%
  arrange(abs(trump_pickup))

#map the data in a diverging choropleth using the percentage points
#of trump swing from 2016 to 2020
precinct_performance %>%
  filter(!is.na(trump_pickup)) %>%
  arrange(abs(trump_pickup)) %>% 
  ggplot(aes(geometry = geometry, fill = trump_pickup, color=trump_pickup)) +
  geom_sf() +
  theme_void() +
  scale_color_distiller(
    type='div',
    direction = -1,
    palette = 'RdBu',
    name = 'Point swing\nin Trump margin,\n2016 to 2020',
    na.value = '#f0f0f0'
  ) +
  scale_fill_distiller(
    type='div',
    direction = -1,
    palette = 'RdBu',
    name = 'Point swing\nin Trump margin,\n2016 to 2020',
    na.value = '#f0f0f0'
  ) +
  labs(caption = "SOURCE: NC State Board of Elections")

#instead of using the area of the shapefiles,
#remap to the centroid of each precinct
#and size on the magnitude of the raw net vote swing
precinct_performance %>%
  filter(!is.na(trump_pickup)) %>%
  arrange(abs(trump_pickup)) %>% 
  ggplot(aes(
    geometry = st_centroid(geometry), 
    size = abs(gop2016+gop2020-(dem2016+dem2020)), 
    color = trump_pickup, 
    alpha = abs(trump_pickup)
    )) +
  geom_sf() +
  theme_void() +
  scale_color_distiller(
    type='div',
    direction = -1,
    limits = c(-20,20),
    oob = squish,
    palette = 'RdBu',
    name = NULL,
    na.value = '#f0f0f0'
  ) +
  scale_size_area(
    #range = c(0.1,5),
    max_size = 5,
    oob = squish,
    limits = c(1,5000),
    name = NULL,
    guide = 'none'
  ) +
  scale_alpha(
    guide = 'none',
    range = c(0.5,0.9),
    oob = squish,
    limits = c(-20,20),
  ) +
  labs(caption = "SOURCE: NC State Board of Elections",
       title = 'Point swing in Trump margin, 2016 to 2020')

#separate out the net gains for Trump/Republicans
#and specify the ranges to keep coloring the same
precinct_performance %>%
  filter(!is.na(trump_pickup)) %>%
  filter(trump_pickup > 0) %>% 
  arrange(abs(trump_pickup)) %>% 
  ggplot(aes(
    geometry = st_centroid(geometry), 
    size = abs(gop2016+gop2020-(dem2016+dem2020)), 
    color=trump_pickup, 
    alpha = abs(trump_pickup)
  )) +
  geom_sf() +
  theme_void() +
  scale_color_distiller(
    type='div',
    direction = -1,
    limits = c(-20,20),
    oob = squish,
    palette = 'RdBu',
    name = NULL,
    na.value = '#f0f0f0'
  ) +
  scale_size_area(
    #range = c(0.1,5),
    max_size = 5,
    oob = squish,
    limits = c(1,5000),
    name = NULL,
    guide = 'none'
  ) +
  scale_alpha(
    guide = 'none',
    range = c(0.5,0.9),
    oob = squish,
    limits = c(-20,20),
  ) +
  labs(caption = "SOURCE: NC State Board of Elections",
       title = 'Point swing in Trump margin, 2016 to 2020')

#separate out the net gains for Biden/Democrats
#and specify the ranges to keep coloring the same
precinct_performance %>%
  filter(!is.na(trump_pickup)) %>%
  filter(trump_pickup < 0) %>% 
  arrange(abs(trump_pickup)) %>% 
  ggplot(aes(
    geometry = st_centroid(geometry), 
    size = abs(gop2016+gop2020-(dem2016+dem2020)), 
    color=trump_pickup, 
    alpha = abs(trump_pickup)
  )) +
  geom_sf() +
  theme_void() +
  scale_color_distiller(
    type='div',
    direction = -1,
    limits = c(-20,20),
    oob = squish,
    palette = 'RdBu',
    name = NULL,
    na.value = '#f0f0f0'
  ) +
  scale_size_area(
    #range = c(0.1,5),
    max_size = 5,
    oob = squish,
    limits = c(1,5000),
    name = NULL,
    guide = 'none'
  ) +
  scale_alpha(
    guide = 'none',
    range = c(0.5,0.9),
    oob = squish,
    limits = c(-20,20),
  ) +
  labs(caption = "SOURCE: NC State Board of Elections",
       title = 'Point swing in Trump margin, 2016 to 2020')

#filter the dot map for flipped precincts only
precinct_performance %>%
  filter(!is.na(trump_pickup)) %>%
  filter(trump_margin2020 * trump_margin2016 < 0) %>% 
  arrange(abs(trump_pickup)) %>% 
  ggplot(aes(
    geometry = st_centroid(geometry), 
    size = abs(gop2016+gop2020-(dem2016+dem2020)), 
    color=trump_pickup, 
    alpha = abs(trump_pickup)
  )) +
  geom_sf() +
  theme_void() +
  scale_color_distiller(
    type='div',
    direction = -1,
    limits = c(-20,20),
    oob = squish,
    palette = 'RdBu',
    name = 'Point swing\nin Trump margin,\n2016 to 2020',
    na.value = '#f0f0f0'
  ) +
  scale_size_area(
    #range = c(0.1,5),
    max_size = 5,
    limits = c(50,500),
    oob = squish,
    name = NULL,
    guide = 'none'
  ) +
  scale_alpha(
    guide = 'none',
    range = c(0.5,0.9),
    oob = squish,
    limits = c(-20,20),
  ) +
  labs(caption = "SOURCE: NC State Board of Elections",
       title = 'Flipped precincts, 2016 to 2020')


# Export to data wrapper --------------------------------------------------

# generate a separate dataframe with centroids split into lat/lng
#using the WGS-84 CRS (EPSG:4326), per datawrapper specs
dw_centroids <- precinct_performance %>% 
  st_transform(4326) %>%
  mutate(centroid = st_centroid(geometry)) %>% 
  mutate(lat = unlist(map(centroid,2)),
         lng = unlist(map(centroid,1))) %>% 
  relocate(lat, .before = 'geometry') %>%
  relocate(lng, .before = 'geometry')

#add some additional calculations into a cleaned up file
#for export for use in datawrapper
dw_centroids %>%
  filter(!is.na(trump_pickup)) %>%
  as.data.frame() %>%
  mutate(swing_pctpt = abs(trump_pickup)) %>% 
  mutate(swing_raw = abs(gop2016+gop2020-(dem2016+dem2020))) %>% 
  mutate(trump_pickup_raw = gop2016+gop2020-(dem2016+dem2020)) %>% 
  rename(trump_pickup_pctpt = trump_pickup) %>% 
  select(id, lat, lng, enr_desc, county_nam,
         trump_pickup_pctpt, trump_pickup_raw, swing_raw, swing_pctpt) %>%
  write.csv('dw_centroids.csv', row.names = FALSE)


# Exploring mismatched precincts ------------------------------------------

#buckets of unmapped/excluded votes:
#number of 2020 votes that could not be mapped to 2020 precincts:
#10,046
#number of 2020 votes across 60 precincts that could not
#be matched to 2016 precincts
#145,819 
#total number of 2020 votes missing from the analysis:
#155,865 (5,287,418/5,443,283 total 2020 votes mapped, or 2.9% missing)

#number of 2016 votes that could not be mapped to 2016 precincts:
#11,922
#number of 2016 votes across 106 precincts that could not
#be matched to 2020 shapes
#128,964
#total number of 2016 votes missing from the analysis:
#140,886 (4,411,494/4,552,380 total 2016 votes mapped, or 3.1% missing)

#number of 2016 and 2020 votes not mapped
#296,751 (of 9,995,663 total 2016/2020 votes, or 3% missing)

#breakdown of these figures below
#5,287,418 total D/R votes mapped
precinct_performance %>% 
  filter(!is.na(trump_pickup)) %>% 
  summarize(total = sum(gop2020) + sum(dem2020))

#145,819 not mapped
precinct_performance %>% 
  filter(is.na(trump_pickup)) %>% 
  summarize(total = sum(gop2020) + sum(dem2020))

#106 precinct shapes from 2016 don't match to 2020 precinct shapes
#for a total of 128,964 votes
nc_precincts_data2016 %>%
  mutate(COUNTY_NAM = toupper(COUNTY_NAM)) %>% 
  distinct(COUNTY_NAM, PREC_ID) %>%
  anti_join(nc_precincts_data, by = c('COUNTY_NAM' = 'county_nam','PREC_ID' = 'prec_id')) %>%
  select(PREC_ID, COUNTY_NAM) %>%
  left_join(
    precinct_sort2016 %>% 
      filter(contest_title == 'US PRESIDENT') %>% 
      filter(candidate_name == 'Hillary Clinton' | candidate_name == 'Donald J. Trump') %>%
      group_by(county, precinct_code) %>%
      summarize(total_dr = sum(vote_ct)),
    by = c('COUNTY_NAM' = 'county', 'PREC_ID' = 'precinct_code')
  ) %>%
  #nrow() %>% 
  adorn_totals()

#4,411,494 total D/R votes mapped from 2016
nc_precincts %>%
  mutate(county_nam = toupper(county_nam)) %>%
  distinct(county_nam, prec_id, .keep_all = TRUE) %>%
  left_join(
    precinct_sort2020 %>% 
      filter(contest_title == 'US PRESIDENT') %>% 
      filter(candidate_name == 'Joseph R. Biden' | candidate_name == 'Donald J. Trump') %>%
      group_by(county, precinct_code) %>%
      summarize(total_dr = sum(vote_ct)) %>% 
      left_join(
        precinct_sort2020 %>%
          filter(contest_title == 'US PRESIDENT') %>% 
          filter(candidate_name == 'Joseph R. Biden') %>%
          group_by(county, precinct_code) %>%
          summarize(dem_votes = sum(vote_ct)),
        by = c('county','precinct_code')
      ) %>% 
      left_join(
        precinct_sort2020 %>%
          filter(contest_title == 'US PRESIDENT') %>% 
          filter(candidate_name == 'Donald J. Trump') %>%
          group_by(county, precinct_code) %>%
          summarize(gop_votes = sum(vote_ct)),
        by = c('county','precinct_code')
      ) %>%
      mutate(trump_margin2020 = round(((gop_votes - dem_votes) / total_dr) * 100, digits = 2) ) %>% 
      rename(gop2020 = gop_votes) %>%
      rename(dem2020 = dem_votes) %>%
      select(county, precinct_code, gop2020, dem2020, trump_margin2020),
    by = c('county_nam' = 'county', 'prec_id' = 'precinct_code' )
  ) %>% 
  left_join(
    nc_precincts_data2016 %>%
      mutate(COUNTY_NAM = toupper(COUNTY_NAM)) %>% 
      distinct(COUNTY_NAM, PREC_ID) %>%
      left_join(
        precinct_sort2016 %>% 
          filter(contest_title == 'US PRESIDENT') %>% 
          filter(candidate_name == 'Hillary Clinton' | candidate_name == 'Donald J. Trump') %>%
          group_by(county, precinct_code) %>%
          summarize(total_dr = sum(vote_ct)) %>% 
          left_join(
            precinct_sort2016 %>% 
              filter(contest_title == 'US PRESIDENT') %>% 
              filter(candidate_name == 'Hillary Clinton') %>%
              group_by(county, precinct_code) %>%
              summarize(dem_votes = sum(vote_ct)),
            by = c('county','precinct_code')
          ) %>% 
          left_join(
            precinct_sort2016 %>% 
              filter(contest_title == 'US PRESIDENT') %>% 
              filter(candidate_name == 'Donald J. Trump') %>%
              group_by(county, precinct_code) %>%
              summarize(gop_votes = sum(vote_ct)),
            by = c('county','precinct_code')
          ) %>% 
          mutate(trump_margin2016 = round(((gop_votes - dem_votes) / total_dr) * 100, digits = 2) ) %>%
          rename(gop2016 = gop_votes) %>%
          rename(dem2016 = dem_votes) %>%
          select(county, precinct_code, gop2016, dem2016, trump_margin2016),
        by = c('COUNTY_NAM' = 'county', 'PREC_ID' = 'precinct_code' )
      ) %>% 
      select(COUNTY_NAM, PREC_ID, gop2016, dem2016, trump_margin2016),
    by = c('county_nam' = 'COUNTY_NAM', 'prec_id' = 'PREC_ID')
  ) %>% 
  #mutate(trump_pickup = trump_margin2020 - trump_margin2016) %>% 
  #relocate(trump_pickup, .after = trump_margin2016) %>% 
  as.data.frame() %>% 
  select(-geometry, -of_prec_id, -blockid, -id) %>% 
  mutate(dr2020 = gop2020 + dem2020) %>% 
  mutate(dr2016 = gop2016 + dem2016) %>% 
  summarize(total2016 = sum(dr2016, na.rm=TRUE))