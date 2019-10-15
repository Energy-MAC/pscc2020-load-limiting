import os

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import scipy.io as io


def retrieve_data(plot_data):
    data = list()
    dir_path = os.path.dirname(os.path.realpath(__file__))
    for file in os.listdir(dir_path):
        if '.csv' in file:
            df = pd.read_csv(dir_path + '/' + file, skiprows=42, delimiter=';|/')
            df.set_index(pd.DatetimeIndex(df.iloc[:, 0]), inplace=True)
            df['year_minute'] = df.index.dayofyear * 1440 + df.index.hour * 60 + df.index.minute
            data.append(df[['GHI','year_minute']])
    master = pd.concat(data, join='outer')
    master = master.resample('1T').mean()
    # master = master.interpolate(method='linear')

    years = master.index.year.unique()
    print(years)

    master['year'] = master.index.year
    master.set_index(master['year_minute'], inplace=True)

    for yr in years:
        print(yr)
        master['ghi_{}'.format(yr)] = master['GHI'][master['year'] == yr]

    master.sort_index(inplace=True)
    master.drop(columns=['year','year_minute','GHI'], inplace=True)
    master['median'] = master.median(axis=1)

    for feature in master.columns:
        if 'ghi_' in feature:
            master[feature].fillna(value=master['median'], inplace=True)
    # master.fillna(value=master['median'], axis=1, inplace=True)
    master = master.drop_duplicates()
    master = master.reindex(np.arange(1, master.index[-1]))
    master.fillna(value=0, inplace=True)
    master = master.loc[1440:, :]
    master.drop(columns='median', inplace=True)

    if plot_data:
        plt.scatter(master.index, master['ghi_2009'], s=1)
        plt.scatter(master.index, master['ghi_2010'], s=1)
        plt.xlabel('Minute of year')
        plt.ylabel('GHI (Wh/m^2)')
        plt.show()

    io.savemat('solar_ghi_data.mat', {'solar_ghi': master.values})

    return master


if __name__ == '__main__':
    df = retrieve_data(plot_data=True)