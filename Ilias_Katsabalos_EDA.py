
# coding: utf-8

# In[1]:


import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
sns.set_style("darkgrid")


# In[2]:


df = pd.read_csv('UKretail.csv', delimiter=',', encoding='ISO-8859-1')
df['total']=df['Quantity']*df['UnitPrice']
Nans = df[df.isnull().any(axis=1)]
df.dropna(how='any', inplace=True)
df['InvoiceDate'] = pd.to_datetime(df['InvoiceDate'])
df['InvoiceDate'] = df['InvoiceDate'].dt.date
df['InvoiceDate'] = pd.to_datetime(df['InvoiceDate'])
#df['CustomerID'] = pd.Series(map(int, df['CustomerID']))
df.shape


# In[3]:


# Average Transaction per day
# We can additionally plot a vertical line to see how data is distributed between calibration and holdout period in 80-20 split
group_days = df.groupby('InvoiceDate')['total'].sum()
group_days
plt.figure()
plt.ylabel('Net Profit')
plt.xlabel('Study Period')
plt.plot(group_days.index, group_days)
plt.title('Net income over study period')
plt.subplots_adjust(left=.2)
plt.axvline(x=group_days.index[round(len(group_days)*0.8)], color='grey', linestyle='dashed')
# There is a big outlier towards the end of the period and it seems like wrong data input
# Apart from that, the split point is correct since there are not big differences in the trend of the plot


# In[4]:


# There is a big return by customer 16446
bigreturn = df[df['InvoiceDate']=='2011-12-09']
bigreturn.loc[bigreturn['total'].idxmin()]


# In[6]:


# Let's see the rest of his transactions
cust16446 = df[df['CustomerID']==16446]
cust16446
# Probably it's a wrong data input


# In[419]:


no_returns = df[df['InvoiceNo'].apply(lambda x: x[0]!='C')]
invoices = no_returns.groupby(['CustomerID', 'InvoiceDate' ,'InvoiceNo']).agg({'total':sum})
invoices.reset_index(inplace=True)


# In[421]:


# We need to find the different transactions per customer. By different, we mean that they occured in different dates
transactions = invoices.groupby('CustomerID').InvoiceDate.nunique()
# Let's plot a pie with the number of repeat and once customers.
repeat = len(transactions[transactions>=2])
non_repeat = len(transactions[transactions==1])
plt.figure()
plt.axis('equal')
plt.title('Repeat and Once Customers')
plt.pie(x=[repeat,non_repeat], labels=['repeat', 'Once'], autopct='%1.1f%%', colors=['darkblue','grey'])


# In[441]:


# Plot the frequency of number of transactions in a histogram. We see a very steep gamma distribution because of the customers
# who boght only once
plt.figure()
plt.hist(transactions.values, bins=50, normed=True)
plt.title('Distribution of number of transactions')
plt.xlabel('Transactions')
plt.ylabel('Customers')
sns.kdeplot(transactions.values)


# In[493]:


# From the above diagram, we exclude the one-timers and plot the repeat customers
repeat_customers = transactions[transactions>1]
plt.figure()
plt.hist(repeat_customers.values, bins=70, normed=True)
plt.title('Distribution of number of transactions')
plt.xlabel('Transactions')
plt.ylabel('Customers')
sns.kdeplot(repeat_customers.values)


# In[500]:


# For each customer plot his lifetime. The date of his last transaction - the day of his first transaction
# Apart from the low frequencies, the company keeps a good hold on their customers
customer_lifetime = invoices.groupby('CustomerID').agg({'InvoiceDate':[min,max]})
customer_lifetime.columns = customer_lifetime.columns.droplevel(0)
customer_lifetime['lifetime'] = pd.to_datetime(customer_lifetime['max']).dt.date-pd.to_datetime(customer_lifetime['min']).dt.date
customer_lifetime['lifetime'] =customer_lifetime['lifetime'].dt.days
plt.figure()
plt.title('Distribution of customers\' lifetime')
plt.xlabel('Lifetimes in Days')
plt.ylabel('Customers')
plt.hist(customer_lifetime['lifetime'].values, bins=20)


# In[ ]:




