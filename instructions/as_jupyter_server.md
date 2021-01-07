# Installation of Jyputer

Install prerequisites:
```
sudo dnf install python3-notebook mathjax sscg
sudo dnf install python3-seaborn python3-lxml python3-basemap python3-scikit-image python3-scikit-learn python3-sympy python3-dask+dataframe python3-nltk
sudo pip3 install xgboost jupyterlab
# this will enable running the server
sudo jupyter serverextension enable --py jupyterlab
```

Set the password for jupyter user:
```
mkdir -p $HOME/.jupyter
jupyter notebook password
```

Generate the security certificates:
```
cd $HOME/.jupyter
sscg
```

It creates 2 certificates:
```
/home/username/.jupyter/sevice.pem
/home/username/.jupyter/sevice-key.pem
```

Create the folders
```
mkdir /storage/Notebooks
```

edit configfile `$HOME/.jupyter/jupyter_notebook_config.json` to have someting alike:
```
{
  "NotebookApp": {
    "nbserver_extensions": {
      "jupyterlab": true
    },
    "password": "sha1:5a938df2490b:ba26ea1932c39e6e4447f5e5cc7391ab8f5ca0c5",
    "ip": "*",
    "allow_origin": "*",
    "allow_remote_access": true,
    "open_browser": false,
    "websocket_compression_options": {},
    "certfile": "/home/username/.jupyter/service.pem",
    "keyfile": "/home/username/.jupyter/service-key.pem",
    "notebook_dir": "/storage/Notebooks"
  }
}
```

*NB! :* When accessing the machine from network: make sure to use `https:\\`, not `http:\\`. Otherwise, it results into `SSL Error`

# Create the config
```
jupyter nbconvert --generate-config
```
It will be stored / created at `$HOME/.jupyter/jupyter_nbconvert_config.py`

Edit it as `nano $HOME/.jupyter/jupyter_nbconvert_config.py`
and  find following lines:
```
## Accept connections from all IPs
c.ServePostProcessor.ip = '*'

## Do not open the browser automatically
c.ServePostProcessor.open_in_browser = False
```


# add 8888 port to firewall exceptions:
```
sudo firewall-cmd --zone=public --permanent --add-port=8888/tcp
sudo firewall-cmd --zone=public --permanent --add-port=8888/udp
sudo firewall-cmd --reload
```

# Add jupyterlab to autostart using systemd:

Create:
```
sudo mkdir -p /opt/jupyterlab/etc/systemd
sudo touch /opt/jupyterlab/etc/systemd/jupyterlab.service
```

Edit `sudo nano /opt/jupyterlab/etc/systemd/jupyterlab.service`:
```
[Unit]
Description=JupyterLab
After=syslog.target network.target
[Service]
User=username
Environment="PATH=/usr/local/bin:/usr/bin:/bin:/usr/local:/home/username/.local/bin"
ExecStart=/usr/local/bin/jupyter notebook --ip 0.0.0.0 --port 8888 --no-browser --allow-root
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target
```

To start server without any security actions (no passwords, etc.):
```
jupyter notebook --LabApp.token=''
```

Enable it:
```
sudo ln -s /opt/jupyterlab/etc/systemd/jupyterlab.service /etc/systemd/system/jupyterlab.service
sudo systemctl daemon-reload
sudo systemctl enable jupyterlab.service
sudo systemctl start jupyterlab.service
sudo systemctl status jupyterlab.service
```

### Adding R to Jupyter

```
# Run R
# I needed to run it with sudo for server
R
# in popped up console type:
install.packages('IRkernel')
# after installation install:
IRkernel::installspec(user = FALSE)
```
