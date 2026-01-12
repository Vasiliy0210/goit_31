#%%
import numpy as np
import matplotlib.pyplot as plt
import scipy.stats as stats
import pandas as pd

1<2 is true

#%%
df=pd.read_csv('/Users/denistkachenko/Documents/marketing_AB.csv')
df.head()
#%%
if "Unnamed: 0" in df.columns:

    df = df.drop(["Unnamed: 0"], axis =1)
#%%
df.rename(columns=lambda x: x.strip().replace(" ", "_"), inplace=True)
df.head(1)
#%%
df["converted_int"] = df['converted'].apply(lambda x:1 if x== True  else  0)
df["converted_int"].sum()
#%%
treatment = df.query('test_group == "ad"')
control = df.query('test_group == "psa"')
#%%

#%%
def permutation_test(df1, df2, n_permutations):
    observed_diff = np.abs(np.mean(df1) - np.mean(df2))
    all_data = np.concatenate([df1, df2])
    count = 0

    for _ in range(n_permutations):
        np.random.shuffle(all_data)
        new_diff = np.abs(np.mean(all_data[0:len(df1)]) - np.mean(all_data[len(df1):]))

        if new_diff >= observed_diff:
            count += 1

    p_value = count / n_permutations

    return p_value

n_permutations = 2000

df1 = treatment['converted_int']
df2 = control['converted_int']

p_value = permutation_test(df1, df2, n_permutations)
print(f'P-Value: {p_value}')

if p_value < 0.05:
    print("We reject null hypothesis. There is a significant difference between the two groups.")
else:
    print("We accept null hypothesis. There is no significant difference between the two groups.")


#%%
import seaborn as sns

#Performing t-test
t_stat, p_val_t = stats.ttest_ind(treatment['converted_int'], control['converted_int'])
print(f'T-Test:\nT-Statistic: {t_stat}\nP-Value: {p_val_t}\n')

#Performing chi-squared test
con_table = pd.crosstab(df['test_group'], df['converted_int'])
chi2, p_val_chi2, dof, expected = stats.chi2_contingency(con_table)
print(f'Chi-Squared Test:\nChi2 Statistic: {chi2}\nP-Value: {p_val_chi2}\n')

#Visualizing
plt.figure(figsize=(15, 5))

#T-Test result visualization
plt.subplot(1, 3, 1)
sns.distplot(treatment['converted_int'], hist = False, kde = True, color = 'blue', label="Treatment Converted")
sns.distplot(control['converted_int'], hist = False, kde = True, color = 'red', label="Control Converted")
plt.title('T-Test Result',fontsize=15)
plt.xlabel('Converted or not', fontsize=13)
plt.ylabel('Density', fontsize=13)
plt.legend()

#chi-square result visualization
plt.subplot(1, 3, 2)
sns.countplot(x='converted_int', hue='test_group', data=df)
plt.title('Chi-squared Test Result',fontsize=15)
plt.xlabel('Converted or not', fontsize=13)
plt.ylabel('Count', fontsize=13)

plt.tight_layout()
plt.show()

#%%

#%%

#%%
