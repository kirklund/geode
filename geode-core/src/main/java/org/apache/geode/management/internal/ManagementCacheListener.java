/*
 * Licensed to the Apache Software Foundation (ASF) under one or more contributor license
 * agreements. See the NOTICE file distributed with this work for additional information regarding
 * copyright ownership. The ASF licenses this file to You under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance with the License. You may obtain a
 * copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software distributed under the License
 * is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
 * or implied. See the License for the specific language governing permissions and limitations under
 * the License.
 */
package org.apache.geode.management.internal;

import javax.management.ObjectName;

import org.apache.logging.log4j.Logger;

import org.apache.geode.cache.EntryEvent;
import org.apache.geode.cache.Region;
import org.apache.geode.cache.util.CacheListenerAdapter;
import org.apache.geode.distributed.DistributedMember;
import org.apache.geode.logging.internal.log4j.api.LogService;

/**
 * This listener is attached to the Monitoring Region to receive any addition or deletion of MBeans.
 * It updates the last refreshed time of proxy once it gets the update request from the Managed
 * Node
 */
class ManagementCacheListener extends CacheListenerAdapter<String, Object> {

  private static final Logger logger = LogService.getLogger();

  private final MBeanProxyFactory proxyHelper;

  private volatile boolean readyForEvents;

  ManagementCacheListener(MBeanProxyFactory proxyHelper) {
    this.proxyHelper = proxyHelper;
    readyForEvents = false;
  }

  @Override
  public void afterCreate(EntryEvent<String, Object> event) {
    if (!readyForEvents) {
      return;
    }
    ObjectName objectName = null;

    try {
      DistributedMember distributedMember = event.getDistributedMember();
      objectName = ObjectName.getInstance(event.getKey());
      Region<String, Object> region = event.getRegion();
      Object newValue = event.getNewValue();

      proxyHelper.createProxy(distributedMember, objectName, region, newValue);
    } catch (Exception e) {
      if (logger.isDebugEnabled()) {
        logger.debug("Proxy Create failed for {} with exception {}", objectName, e.getMessage(), e);
      }
    }
  }

  @Override
  public void afterDestroy(EntryEvent<String, Object> event) {
    ObjectName objectName = null;

    try {
      DistributedMember distributedMember = event.getDistributedMember();
      objectName = ObjectName.getInstance(event.getKey());
      Object oldValue = event.getOldValue();

      proxyHelper.removeProxy(distributedMember, objectName, oldValue);
    } catch (Exception e) {
      if (logger.isDebugEnabled()) {
        logger.debug("Proxy Destroy failed for {} with exception {}", objectName, e.getMessage(),
            e);
      }
    }
  }

  @Override
  public void afterUpdate(EntryEvent<String, Object> event) {
    ObjectName objectName = null;
    try {
      if (!readyForEvents) {
        return;
      }

      objectName = ObjectName.getInstance(event.getKey());
      ProxyInfo proxyInfo = proxyHelper.findProxyInfo(objectName);
      if (proxyInfo == null) {
        return;
      }

      ProxyInterface proxy = (ProxyInterface) proxyInfo.getProxyInstance();
      // Will return null if proxy is filtered out
      if (proxy != null) {
        proxy.setLastRefreshedTime(System.currentTimeMillis());
      }

      proxyHelper.updateProxy(objectName, proxyInfo, event.getNewValue(), event.getOldValue());

    } catch (Exception e) {
      if (logger.isDebugEnabled()) {
        logger.debug("Proxy Update failed for {} with exception {}", objectName, e.getMessage(), e);
      }
    }
  }

  void markReady() {
    readyForEvents = true;
  }
}
